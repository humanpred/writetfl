# test-export_tfl_page.R — Tests for export_tfl_page.R
#
# End-to-end smoke tests are in test-integration.R.  This file covers
# edge-case branches specific to export_tfl_page().

library(ggplot2)

# Recursively collect every text-grob label from a captured grid gTree.
# Used to assert that a leaked literal "NA" annotation never reaches the page.
collect_text_labels <- function(g) {
  labs <- character(0)
  if (inherits(g, "text") && !is.null(g$label)) {
    labs <- c(labs, as.character(g$label))
  }
  if (!is.null(g$children)) {
    for (nm in names(g$children)) {
      labs <- c(labs, collect_text_labels(g$children[[nm]]))
    }
  }
  labs
}

# Render one page with character content (so the only text grobs are the
# body plus whichever annotations are present) and return all text labels.
labels_for_page <- function(...) {
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  export_tfl_page(list(content = "BODYTEXT"), ..., preview = TRUE)
  collect_text_labels(grid::grid.grab())
}

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
# A single NA is treated the same as NULL (absent) — issue: data-driven pages
# ---------------------------------------------------------------------------

test_that("labels_for_page sanity: a real annotation appears, NULL does not", {
  # Positive control: a supplied header text is actually rendered.
  expect_true("REALHEADER" %in% labels_for_page(header_left = "REALHEADER"))
  # Negative control: omitting it produces no such label.
  expect_false("REALHEADER" %in% labels_for_page())
})

test_that("export_tfl_page treats a single NA annotation as absent (no 'NA' drawn)", {
  text_args <- c("header_left", "header_center", "header_right",
                 "caption", "footnote",
                 "footer_left", "footer_center", "footer_right")
  for (arg in text_args) {
    labels <- do.call(labels_for_page, stats::setNames(list(NA), arg))
    expect_false("NA" %in% labels,
                 info = paste0(arg, " = NA leaked a literal 'NA' label"))
  }
})

test_that("export_tfl_page: NA annotation renders identically to NULL", {
  # All eight annotations NA should yield the same label set as none supplied.
  all_na <- labels_for_page(
    header_left = NA, header_center = NA, header_right = NA,
    caption = NA, footnote = NA,
    footer_left = NA, footer_center = NA, footer_right = NA
  )
  none <- labels_for_page()
  expect_setequal(all_na, none)
  expect_equal(none, "BODYTEXT")
})

test_that("export_tfl_page: NA in x list override blanks a global annotation", {
  # x list element (NA) takes precedence over the direct argument and, being a
  # single NA, blanks the section rather than rendering "NA".
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  export_tfl_page(
    list(content = "BODYTEXT", caption = NA),
    caption = "GLOBALCAPTION",
    preview = TRUE
  )
  labs <- collect_text_labels(grid::grid.grab())
  expect_false("GLOBALCAPTION" %in% labs)
  expect_false("NA" %in% labs)
})

test_that("export_tfl_page keeps NA embedded in a multi-line annotation", {
  # Boundary: only a *single* NA is absent; a vector with NA among real values
  # is collapsed with "\n" and drawn verbatim.
  labels <- labels_for_page(caption = c("A", NA, "B"))
  expect_true("A\nNA\nB" %in% labels)
})

test_that("export_tfl_page treats a single NA page_i the same as NULL", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 4, height = 3)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  err <- tryCatch(
    export_tfl_page(list(content = p),
      caption  = paste(rep("caption line", 30), collapse = "\n"),
      footnote = paste(rep("footnote line", 30), collapse = "\n"),
      page_i   = NA
    ),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "Content height")
  expect_false(grepl("Page", err))
})

test_that("export_tfl_page treats a single NA rule the same as FALSE", {
  # NA rule must not error (it did before: fell through normalize_rule's abort).
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(
    export_tfl_page(list(content = "BODY"),
      header_left = "H", footer_left = "F",
      header_rule = NA, footer_rule = NA,
      preview = TRUE
    )
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

# ---------------------------------------------------------------------------
# overflow_action — page-level grob width check (issue #30)
# ---------------------------------------------------------------------------

test_that("non-table grob wider than the content viewport errors by default", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  wide_grob <- grid::rectGrob(width = grid::unit(20, "inches"))
  expect_error(
    export_tfl_page(list(content = wide_grob)),
    "exceeds available content width"
  )
})

test_that("non-table grob overflow can be downgraded to a warning", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  wide_grob <- grid::rectGrob(width = grid::unit(20, "inches"))
  expect_warning(
    export_tfl_page(list(content = wide_grob), overflow_action = "warn"),
    "exceeds available content width"
  )
})

test_that("ggplot content does not trigger the page-level width check (it scales)", {
  skip_if_not_installed("ggplot2")
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, hp)) + ggplot2::geom_point()
  expect_no_error(export_tfl_page(list(content = p)))
})

test_that("character content does not trigger the page-level width check (it word-wraps)", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  long <- paste(rep("word", 200), collapse = " ")
  expect_no_error(export_tfl_page(list(content = long)))
})

test_that("page-level overflow message includes the diagnostic-mode hint", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  wide_grob <- grid::rectGrob(width = grid::unit(20, "inches"))
  expect_error(
    export_tfl_page(list(content = wide_grob)),
    "overflow_action = \"warn\""
  )
})

# ---------------------------------------------------------------------------
# Tab handling in character content (advanced `...` knobs)
# ---------------------------------------------------------------------------

test_that("tabbed character content renders without the device tab warning", {
  # If tabs reached the device unconverted, drawing would warn
  # "font width unknown for character 0x09".  Conversion to spaces must
  # prevent that.
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_warning(
    export_tfl_page(list(content = "\tIndented line\nNormal\twith infix tab")),
    regexp = NA
  )
})

test_that("export_tfl_page accepts tab_indent_spaces / tab_infix_spaces via ...", {
  # The knobs are not consumed by export_tfl_page(); they flow through `...`
  # to the caption / footnote / content wrap where .convert_tabs() applies
  # them (and absorbs any other forwarded `...`, e.g. overlap_warn_mm).
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 8.5, height = 11)
  on.exit({ grDevices::dev.off(); unlink(f) })

  expect_no_error(
    export_tfl_page(list(content = "\tindented"),
                    tab_indent_spaces = 4L, tab_infix_spaces = 2L,
                    overlap_warn_mm = 2)
  )
})
