library(ggplot2)

# Helper: a simple ggplot for use in all tests
make_plot <- function(title = NULL) {
  p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
  if (!is.null(title)) p <- p + ggtitle(title)
  p
}

# Helper: run export_tfl to a tempfile, clean up after
with_pdf <- function(x, ...) {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  export_tfl(x, file = f, ...)
  expect_true(file.exists(f))
  expect_gt(file.size(f), 0)
  invisible(f)
}

# --- Basic rendering ----------------------------------------------------------

test_that("single ggplot renders to PDF without error", {
  expect_no_error(with_pdf(make_plot()))
})

test_that("list of ggplots renders multi-page PDF without error", {
  plots <- list(
    list(content = make_plot("Page 1")),
    list(content = make_plot("Page 2")),
    list(content = make_plot("Page 3"))
  )
  expect_no_error(with_pdf(plots))
})

# --- Text sections ------------------------------------------------------------

test_that("header_left and footer_right render without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left  = "My Report",
    footer_right = "Page 1"
  ))
})

test_that("all header and footer elements render without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left   = "Left",
    header_center = "Center",
    header_right  = "Right",
    footer_left   = "FL",
    footer_center = "FC",
    footer_right  = "FR"
  ))
})

test_that("caption renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left = "Report",
    caption     = "Figure 1. A scatter plot of weight vs MPG."
  ))
})

test_that("footnote renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    footnote = "Data source: mtcars dataset."
  ))
})

test_that("multi-line caption as character vector renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    caption = c("Figure 1. Line one of the caption.",
                "Line two of the caption with additional detail.")
  ))
})

test_that("multi-line caption with embedded newline renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    caption = "Figure 1. First line.\nSecond line of caption."
  ))
})

test_that("multi-line footnote renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    footnote = c("Footnote line 1.", "Footnote line 2.")
  ))
})

# --- Rules --------------------------------------------------------------------

test_that("header_rule = TRUE renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left = "Header",
    header_rule = TRUE
  ))
})

test_that("footer_rule = 0.5 renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    footer_right = "Footer",
    footer_rule  = 0.5
  ))
})

test_that("header_rule as linesGrob renders without error", {
  my_rule <- grid::linesGrob(
    x  = grid::unit(c(0, 1), "npc"),
    y  = grid::unit(c(0.5, 0.5), "npc"),
    gp = grid::gpar(col = "steelblue", lwd = 1.5)
  )
  expect_no_error(with_pdf(
    make_plot(),
    header_left = "Header",
    header_rule = my_rule
  ))
})

# --- Page numbering -----------------------------------------------------------

test_that("page_num glue substitution works correctly", {
  plots <- list(
    list(content = make_plot("P1")),
    list(content = make_plot("P2"))
  )
  # We can't inspect the rendered text, but we can confirm no error
  expect_no_error(with_pdf(plots, page_num = "Page {i} of {n}"))
})

test_that("footer_right in x[[i]] overrides page_num", {
  plots <- list(
    list(content = make_plot(), footer_right = "Appendix A")
  )
  expect_no_error(with_pdf(plots, page_num = "Page {i} of {n}"))
})

test_that("page_num = NULL disables auto page numbering", {
  expect_no_error(with_pdf(make_plot(), page_num = NULL))
})

# --- gp typography ------------------------------------------------------------

test_that("gp as bare gpar() renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left = "Header",
    gp          = grid::gpar(fontsize = 10)
  ))
})

test_that("gp as named list renders without error", {
  expect_no_error(with_pdf(
    make_plot(),
    header_left = "Header",
    footer_right = "Footer",
    caption     = "A caption.",
    gp = list(
      header  = grid::gpar(fontsize = 11, fontface = "bold"),
      footer  = grid::gpar(fontsize =  8, col = "gray50"),
      caption = grid::gpar(fontsize =  9, fontface = "italic"),
      header_left = grid::gpar(fontsize = 13)
    )
  ))
})

# --- Device lifecycle ---------------------------------------------------------

test_that("export_tfl closes device on error mid-loop", {
  plots <- list(
    list(content = make_plot("Good page")),
    list(content = "not a ggplot")  # will error
  )
  f        <- tempfile(fileext = ".pdf")
  n_before <- length(grDevices::dev.list())
  expect_error(export_tfl(plots, file = f))
  expect_equal(length(grDevices::dev.list()), n_before)
  unlink(f)
})

test_that("export_tfl returns invisible path", {
  f      <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  result <- export_tfl(make_plot(), file = f)
  expect_true(is.character(result))
  expect_true(endsWith(result, ".pdf"))
})

# --- preview mode -------------------------------------------------------------

test_that("preview = TRUE draws to current device without error", {
  p <- make_plot()
  f <- tempfile(fileext = ".pdf")
  on.exit({ grDevices::dev.off(); unlink(f) })
  grDevices::pdf(f, width = 11, height = 8.5)
  expect_no_error(
    export_tfl_page(
      x       = list(content = p),
      preview = TRUE
    )
  )
})

test_that("preview = TRUE with full layout renders without error", {
  p <- make_plot()
  f <- tempfile(fileext = ".pdf")
  on.exit({ grDevices::dev.off(); unlink(f) })
  grDevices::pdf(f, width = 11, height = 8.5)
  expect_no_error(
    export_tfl_page(
      x             = list(content = p),
      header_left   = "Report Title",
      header_right  = "2026-01-01",
      caption       = "Figure 1. Caption text.",
      footnote      = "Source: mtcars.",
      footer_center = "Confidential",
      footer_right  = "Page 1",
      header_rule   = TRUE,
      footer_rule   = 0.8,
      preview       = TRUE
    )
  )
})

# --- Layout error handling ----------------------------------------------------

test_that("content too short produces informative error", {
  # Squeeze margins to force very little space for the content
  # Use many tall sections + tiny page height
  p <- make_plot()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_error(
    export_tfl(
      p,
      file      = f,
      pg_height = 3,   # very short page
      pg_width  = 11,
      margins   = grid::unit(c(t=1, r=0.5, b=1, l=0.5), "inches"),
      header_left  = "Header",
      caption      = paste(rep("Very long caption line. ", 10), collapse = ""),
      footnote     = paste(rep("Footnote text. ", 10), collapse = ""),
      footer_right = "Page 1",
      min_content_height = grid::unit(3, "inches")
    ),
    regexp = "Content height"
  )
})

test_that("overlap near-miss produces warning not error", {
  p <- make_plot()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  # On a narrow page, put long text left and right with no center
  expect_warning(
    export_tfl(
      p,
      file          = f,
      pg_width      = 5,
      pg_height     = 4,
      margins       = grid::unit(c(t=0.25, r=0.25, b=0.25, l=0.25), "inches"),
      header_left   = paste(rep("Long header left text ", 1), collapse = ""),
      header_right  = paste(rep("Long header right text ", 1), collapse = ""),
      min_content_height = grid::unit(1, "inches"),
      overlap_warn_mm = 50   # very aggressive threshold to force warning
    )
  )
})

test_that("invalid file extension raises error before opening device", {
  expect_error(
    export_tfl(make_plot(), file = "output.docx"),
    regexp = "\\.pdf"
  )
  # Confirm no device was opened
  # (hard to test directly, but the error should occur before pdf())
})

test_that("x with no content element raises informative error", {
  expect_error(
    export_tfl(
      list(list(caption = "no content here")),
      file = tempfile(fileext = ".pdf")
    ),
    regexp = "content"
  )
})
