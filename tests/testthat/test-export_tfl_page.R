# test-export_tfl_page.R — Tests for export_tfl_page.R
#
# End-to-end smoke tests are in test-integration.R.  This file covers
# edge-case branches specific to export_tfl_page().

library(ggplot2)

# ---------------------------------------------------------------------------
# Input validation
# ---------------------------------------------------------------------------

test_that("export_tfl_page errors when x has no content element", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_error(export_tfl_page(list(caption = "No content")), regexp = "content")
  expect_error(export_tfl_page("not a list"), regexp = "content")
})

test_that("export_tfl_page errors on non-unit margins/padding/min_content_height", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  pg <- list(content = p)

  expect_error(export_tfl_page(pg, margins = 0.5), regexp = "margins")
  expect_error(export_tfl_page(pg, padding = 0.5), regexp = "padding")
  expect_error(export_tfl_page(pg, min_content_height = 3), regexp = "min_content_height")
})

test_that("export_tfl_page errors on invalid caption_just / footnote_just", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  pg <- list(content = p)

  expect_error(export_tfl_page(pg, caption_just = "top"), regexp = "left.*right.*centre")
  expect_error(export_tfl_page(pg, footnote_just = "bottom"), regexp = "left.*right.*centre")
})

# ---------------------------------------------------------------------------
# Argument resolution from x list elements
# ---------------------------------------------------------------------------

test_that("export_tfl_page resolves per-page overrides from x", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  page <- list(
    content      = p,
    header_left  = "Per-page header",
    caption      = "Per-page caption",
    footnote     = "Per-page footnote",
    footer_right = "Per-page footer"
  )

  # Direct args should be overridden by x list elements
  expect_no_error(
    export_tfl_page(page,
      header_left  = "Default header",
      caption      = "Default caption",
      footnote     = "Default footnote",
      footer_right = "Default footer"
    )
  )
})

# ---------------------------------------------------------------------------
# overlap_warn_mm via dots
# ---------------------------------------------------------------------------

test_that("export_tfl_page passes overlap_warn_mm = NULL to disable detection", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  # Use very long header text that would normally trigger overlap
  long_text <- paste(rep("X", 200), collapse = "")
  expect_no_error(
    export_tfl_page(list(content = p),
      header_left  = long_text,
      header_right = long_text,
      overlap_warn_mm = NULL
    )
  )
})

# ---------------------------------------------------------------------------
# Page error prefix
# ---------------------------------------------------------------------------

test_that("export_tfl_page includes page_i prefix in error messages", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 4, height = 3)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  long_header <- paste(rep("A very long header text", 20), collapse = " ")
  long_footer <- paste(rep("A very long footer text", 20), collapse = " ")

  expect_error(
    export_tfl_page(list(content = p),
      header_left = long_header,
      footer_left = long_footer,
      caption     = paste(rep("caption line", 20), collapse = "\n"),
      footnote    = paste(rep("footnote line", 20), collapse = "\n"),
      page_i      = 5
    ),
    "Page 5"
  )
})

test_that("export_tfl_page omits page prefix when page_i is NULL", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 4, height = 3)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_error(
    export_tfl_page(list(content = p),
      caption  = paste(rep("caption line", 30), collapse = "\n"),
      footnote = paste(rep("footnote line", 30), collapse = "\n")
    ),
    "Content height"
  )
})

# ---------------------------------------------------------------------------
# Section presence logic — no optional sections
# ---------------------------------------------------------------------------

test_that("export_tfl_page renders with only content (no annotations)", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_no_error(export_tfl_page(list(content = p)))
})

# ---------------------------------------------------------------------------
# Rules drawn in padding gap
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Word wrapping of caption and footnote
# ---------------------------------------------------------------------------

test_that("export_tfl_page wraps long caption within viewport width", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 6, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  long_caption <- paste(rep("word", 80), collapse = " ")
  # Should not error — text wraps instead of overflowing
  expect_no_error(
    export_tfl_page(list(content = p), caption = long_caption)
  )
})

test_that("export_tfl_page wraps long footnote within viewport width", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 6, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  long_footnote <- paste(rep("word", 80), collapse = " ")
  expect_no_error(
    export_tfl_page(list(content = p), footnote = long_footnote)
  )
})

test_that("export_tfl_page wraps both caption and footnote on narrow page", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 4, height = 11)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  long_text <- paste(rep("longword", 40), collapse = " ")
  expect_no_error(
    export_tfl_page(list(content = p),
      caption  = long_text,
      footnote = long_text,
      header_left = "Title"
    )
  )
})

# ---------------------------------------------------------------------------
# Rules drawn in padding gap
# ---------------------------------------------------------------------------

test_that("export_tfl_page renders header and footer rules together", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_no_error(
    export_tfl_page(list(content = p),
      header_left = "Header",
      footer_left = "Footer",
      header_rule = 0.8,
      footer_rule = TRUE
    )
  )
})

# ---------------------------------------------------------------------------
# Character string content and content_just
# ---------------------------------------------------------------------------

test_that("export_tfl_page renders a character string as content without error", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_no_error(
    export_tfl_page(list(content = "This is plain text content."),
                    header_left = "Title", footer_left = "Footer")
  )
})

test_that("export_tfl_page renders a character vector as content (joined by newline)", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_no_error(
    export_tfl_page(list(content = c("First paragraph.", "Second paragraph.")))
  )
})

test_that("export_tfl_page errors on invalid content_just", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_error(
    export_tfl_page(list(content = "text"), content_just = "center"),
    regexp = "left.*right.*centre"
  )
})

test_that("export_tfl_page content_just right and centre render without error", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_no_error(
    export_tfl_page(list(content = "Right-aligned text"), content_just = "right")
  )
  expect_no_error(
    export_tfl_page(list(content = "Centred text"), content_just = "centre")
  )
})

test_that("per-page content_just override in x list is respected", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  pg <- list(content = "Override test", content_just = "right")
  expect_no_error(export_tfl_page(pg, content_just = "left"))
})

test_that("gp$content controls character content typography", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_no_error(
    export_tfl_page(
      list(content = "Styled text"),
      gp = list(content = grid::gpar(fontsize = 14, fontface = "bold"))
    )
  )
})
