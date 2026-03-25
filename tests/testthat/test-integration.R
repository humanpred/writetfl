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

test_that("single grob renders to PDF without error", {
  g <- grid::rectGrob(width = grid::unit(0.5, "npc"),
                      height = grid::unit(0.5, "npc"))
  expect_no_error(with_pdf(g))
})

test_that("single character string renders to PDF without error", {
  expect_no_error(with_pdf("This is plain text content on a PDF page."))
})

test_that("character vector renders to PDF without error (joined by newline)", {
  expect_no_error(with_pdf(c("First paragraph.", "Second paragraph.")))
})

test_that("grob in page list renders to PDF without error", {
  g <- grid::textGrob("Table placeholder")
  plots <- list(
    list(content = make_plot("Page 1")),
    list(content = g, caption = "A grob page")
  )
  expect_no_error(with_pdf(plots))
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

test_that("page_num rejects non-string values", {
  expect_error(with_pdf(make_plot(), page_num = 42), regexp = "page_num")
  expect_error(with_pdf(make_plot(), page_num = c("a", "b")), regexp = "page_num")
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
    list(content = 42L)  # will error — numeric is not a valid content type
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

test_that("preview = TRUE with grob content renders without error", {
  g <- grid::rectGrob(width = grid::unit(0.8, "npc"),
                      height = grid::unit(0.8, "npc"))
  f <- tempfile(fileext = ".pdf")
  on.exit({ grDevices::dev.off(); unlink(f) })
  grDevices::pdf(f, width = 11, height = 8.5)
  expect_no_error(
    export_tfl_page(
      x       = list(content = g),
      caption = "A grob content area.",
      preview = TRUE
    )
  )
})

test_that("non-ggplot non-grob content raises informative error", {
  # Must call export_tfl_page directly: export_tfl validates via
  # coerce_x_to_pagelist first, so draw_content's error branch is only
  # reachable by bypassing that validation.
  f <- tempfile(fileext = ".pdf")
  on.exit({ grDevices::dev.off(); unlink(f) })
  grDevices::pdf(f, width = 11, height = 8.5)
  expect_error(
    export_tfl_page(x = list(content = list(not = "a plot"))),
    regexp = "ggplot"
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

test_that("export_tfl_page layout error has no page prefix when page_i not supplied", {
  f <- tempfile(fileext = ".pdf")
  on.exit({ grDevices::dev.off(); unlink(f) })
  grDevices::pdf(f, width = 11, height = 8.5)
  expect_error(
    export_tfl_page(
      x                  = list(content = make_plot()),
      min_content_height = grid::unit(100, "inches")
    ),
    regexp = "^Content height"  # no "Page X:" prefix when page_i is NULL
  )
})

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

# --- export_tfl() preview mode -----------------------------------------------

# Helper: open a scratch PDF device, run expr, close and delete on exit.
.with_pdf_dev <- function(expr) {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) }, add = TRUE)
  force(expr)
}

test_that("export_tfl(preview = TRUE) renders a single plot and returns NULL invisibly", {
  .with_pdf_dev({
    result <- export_tfl(make_plot(), preview = TRUE)
    expect_null(result)
  })
})

test_that("export_tfl(preview = TRUE) renders all pages of a multi-page list", {
  plots <- list(list(content = make_plot()), list(content = make_plot()))
  .with_pdf_dev({
    expect_no_error(export_tfl(plots, preview = TRUE))
  })
})

test_that("export_tfl(preview = integer vector) renders only the selected pages", {
  plots <- list(
    list(content = make_plot()),
    list(content = make_plot()),
    list(content = make_plot())
  )
  .with_pdf_dev({
    expect_no_error(export_tfl(plots, preview = c(1L, 3L)))
  })
})

test_that("export_tfl(preview) aborts with informative message on out-of-range index", {
  .with_pdf_dev({
    expect_error(export_tfl(make_plot(), preview = 99L), regexp = "out of range")
  })
})

test_that("export_tfl(preview = TRUE) renders a tfl_table without writing a file", {
  tbl <- tfl_table(
    data.frame(a = letters[1:3], b = 1:3),
    col_labels = c(a = "Letter", b = "Number")
  )
  .with_pdf_dev({
    expect_no_error(export_tfl(tbl, preview = TRUE))
  })
})

test_that("export_tfl(preview = 1) renders just the first page of a tfl_table", {
  tbl <- tfl_table(data.frame(a = letters[1:3], b = 1:3))
  .with_pdf_dev({
    expect_no_error(export_tfl(tbl, preview = 1L))
  })
})

# --- tfl_table row_rule -------------------------------------------------------

test_that("tfl_table with row_rule = TRUE renders to PDF without error", {
  tbl <- tfl_table(data.frame(a = letters[1:5], b = 1:5), row_rule = TRUE)
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})

# --- tfl_table cell background shading ---------------------------------------

test_that("tfl_table with header and data row fill renders to PDF without error", {
  df  <- data.frame(grp = c("A", "A", "B", "B"), val = 1:4,
                    stringsAsFactors = FALSE)
  tbl <- dplyr::group_by(df, grp) |>
    tfl_table(gp = list(
      header_row = grid::gpar(fontface = "bold", fill = "lightblue"),
      data_row   = grid::gpar(fill = c("white", "gray95"))
    ))
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})

test_that("tfl_table with fill_by = 'group' renders to PDF without error", {
  df  <- data.frame(grp = c("A", "A", "B", "B"), val = 1:4,
                    stringsAsFactors = FALSE)
  tbl <- dplyr::group_by(df, grp) |>
    tfl_table(gp = list(data_row = grid::gpar(fill = c("white", "gray95"))),
              fill_by = "group")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})
