skip_if_not_installed("flextable")

# Helper: build a simple flextable
make_ft <- function(caption = NULL, footer_lines = NULL, footnotes = NULL) {
  ft <- flextable::flextable(head(mtcars[, 1:4], 5))
  if (!is.null(caption)) {
    ft <- flextable::set_caption(ft, caption)
  }
  if (!is.null(footer_lines)) {
    ft <- flextable::add_footer_lines(ft, footer_lines)
  }
  if (!is.null(footnotes)) {
    for (i in seq_along(footnotes)) {
      ft <- flextable::footnote(
        ft, i = i, j = 1, part = "body",
        value = flextable::as_paragraph(footnotes[[i]]),
        ref_symbols = as.character(i)
      )
    }
  }
  ft
}

# .extract_flextable_annotations() ----------------------------------------

test_that("caption extracted from set_caption()", {
  ft <- make_ft(caption = "My Caption")
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_equal(annot$caption, "My Caption")
})

test_that("NULL caption when none set", {
  ft <- make_ft()
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_null(annot$caption)
})

test_that("NULL caption when empty string", {
  ft <- flextable::flextable(head(mtcars, 3))
  ft <- flextable::set_caption(ft, "")
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_null(annot$caption)
})

test_that("footnotes extracted from add_footer_lines()", {
  ft <- make_ft(footer_lines = c("Footer 1", "Footer 2"))
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_equal(annot$footnote, "Footer 1\nFooter 2")
})

test_that("footnotes extracted from footnote()", {
  ft <- make_ft(footnotes = c("Note A", "Note B"))
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_true(grepl("Note A", annot$footnote))
  expect_true(grepl("Note B", annot$footnote))
})

test_that("NULL footnote when no footer rows", {
  ft <- make_ft()
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_null(annot$footnote)
})

test_that("caption and footnote extracted together", {
  ft <- make_ft(caption = "Title", footer_lines = "Source: test data.")
  annot <- writetfl:::.extract_flextable_annotations(ft)
  expect_equal(annot$caption, "Title")
  expect_equal(annot$footnote, "Source: test data.")
})

# .clean_flextable() ------------------------------------------------------

test_that("footer rows removed by .clean_flextable()", {
  ft <- make_ft(footer_lines = c("Footer 1", "Footer 2"))
  expect_equal(flextable::nrow_part(ft, "footer"), 2L)
  cleaned <- writetfl:::.clean_flextable(ft)
  expect_equal(flextable::nrow_part(cleaned, "footer"), 0L)
})

test_that(".clean_flextable is no-op when no footer rows", {
  ft <- make_ft()
  cleaned <- writetfl:::.clean_flextable(ft)
  expect_equal(flextable::nrow_part(cleaned, "footer"), 0L)
})

# .flextable_grob_height() ------------------------------------------------

test_that(".flextable_grob_height returns positive numeric", {
  ft <- make_ft()
  grob <- flextable::gen_grob(ft, fit = "auto")
  h <- writetfl:::.flextable_grob_height(grob)
  expect_true(is.numeric(h))
  expect_true(h > 0)
})

# .flextable_to_grob() ----------------------------------------------------

test_that(".flextable_to_grob returns a flextableGrob", {
  ft <- make_ft()
  grob <- writetfl:::.flextable_to_grob(ft, content_w = 10)
  expect_true(inherits(grob, "flextableGrob"))
  expect_true(inherits(grob, "grob"))
})

test_that(".flextable_to_grob scales to content width", {
  ft <- make_ft()
  grob <- writetfl:::.flextable_to_grob(ft, content_w = 8)
  total_w <- sum(grob$ftpar$widths)
  # Should be approximately 8 inches (within tolerance for rounding)
  expect_true(abs(total_w - 8) < 0.5)
})

# .flextable_content_height() ---------------------------------------------

test_that(".flextable_content_height returns positive numeric", {
  annot <- list(caption = "Title", footnote = "Footer")
  h <- writetfl:::.flextable_content_height(11, 8.5, list(), "Page {i} of {n}",
                                            annot)
  expect_true(is.numeric(h))
  expect_true(h > 0)
  expect_true(h < 8.5)
})

test_that(".flextable_content_height respects custom dots", {
  annot <- list(caption = NULL, footnote = NULL)
  h1 <- writetfl:::.flextable_content_height(11, 8.5, list(), "Page {i} of {n}",
                                             annot)
  h2 <- writetfl:::.flextable_content_height(11, 8.5,
                                             list(header_left = "Big Header"),
                                             "Page {i} of {n}", annot)
  expect_true(h1 > h2)
})

test_that(".flextable_content_height respects custom margins via dots", {
  annot <- list(caption = NULL, footnote = NULL)
  big_margins <- grid::unit(c(2, 2, 2, 2), "inches")
  h <- writetfl:::.flextable_content_height(11, 8.5,
                                            list(margins = big_margins),
                                            "Page {i} of {n}", annot)
  expect_true(is.numeric(h))
  expect_true(h > 0)
  expect_true(h < 4.5)  # 8.5 - 4 inches of margins
})

# .flextable_content_width() ----------------------------------------------

test_that(".flextable_content_width returns positive numeric", {
  w <- writetfl:::.flextable_content_width(11, list())
  expect_true(is.numeric(w))
  expect_true(w > 0)
  expect_true(w < 11)
})

test_that(".flextable_content_width respects custom margins", {
  custom_margins <- grid::unit(c(1, 1, 1, 1), "inches")
  w <- writetfl:::.flextable_content_width(11, list(margins = custom_margins))
  expect_equal(w, 9)
})

# flextable_to_pagelist() -------------------------------------------------

test_that("flextable_to_pagelist returns page spec with content and annotations", {
  ft <- make_ft(caption = "My Title", footer_lines = "My Footer")
  pages <- writetfl:::flextable_to_pagelist(ft)
  expect_true(is.list(pages))
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1L]]$content, "grob"))
  expect_equal(pages[[1L]]$caption, "My Title")
  expect_equal(pages[[1L]]$footnote, "My Footer")
})

test_that("flextable_to_pagelist works without annotations", {
  ft <- make_ft()
  pages <- writetfl:::flextable_to_pagelist(ft)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1L]]$content, "grob"))
  expect_null(pages[[1L]]$caption)
  expect_null(pages[[1L]]$footnote)
})

# .rebuild_flextable_subset() ---------------------------------------------

test_that(".rebuild_flextable_subset creates valid sub-flextable", {
  ft <- make_ft()
  sub_ft <- writetfl:::.rebuild_flextable_subset(ft, 1:3)
  expect_true(inherits(sub_ft, "flextable"))
  expect_equal(flextable::nrow_part(sub_ft, "body"), 3L)
})

test_that(".rebuild_flextable_subset preserves header", {
  ft <- make_ft()
  sub_ft <- writetfl:::.rebuild_flextable_subset(ft, 1:2)
  expect_equal(flextable::nrow_part(sub_ft, "header"),
               flextable::nrow_part(ft, "header"))
})

test_that(".rebuild_flextable_subset preserves column widths", {
  ft <- make_ft()
  sub_ft <- writetfl:::.rebuild_flextable_subset(ft, 1:2)
  expect_equal(sub_ft$body$colwidths, ft$body$colwidths)
})

# .paginate_flextable() ---------------------------------------------------

test_that(".paginate_flextable splits tall table into multiple pages", {
  # Create a table with many rows
  big_ft <- flextable::flextable(mtcars[, 1:4])
  big_ft <- writetfl:::.clean_flextable(big_ft)

  # Use a very small content height to force pagination
  pages <- writetfl:::.paginate_flextable(big_ft, content_h = 1.5, content_w = 10)
  expect_true(length(pages) > 1L)
  # All pages should be flextable objects
  for (p in pages) {
    expect_true(inherits(p, "flextable"))
  }
  # Total rows across pages should equal original
  total_rows <- sum(vapply(pages, function(p) {
    flextable::nrow_part(p, "body")
  }, integer(1L)))
  expect_equal(total_rows, nrow(mtcars))
})

# End-to-end: export_tfl() ------------------------------------------------

test_that("export_tfl writes PDF from flextable", {
  ft <- make_ft(caption = "Test Table")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  result <- export_tfl(ft, file = tmp)
  expect_true(file.exists(tmp))
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("export_tfl preview mode works with flextable", {
  ft <- make_ft()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(ft, preview = TRUE)
  expect_null(result)
})

test_that("export_tfl preview with specific pages works", {
  ft <- make_ft()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(ft, preview = 1L)
  expect_null(result)
})

# List of flextable objects -----------------------------------------------

test_that("export_tfl handles list of flextable objects", {
  ft1 <- make_ft(caption = "Table 1")
  ft2 <- make_ft(caption = "Table 2")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  result <- export_tfl(list(ft1, ft2), file = tmp)
  expect_true(file.exists(tmp))
})

test_that("export_tfl preview with list of flextable objects", {
  ft1 <- make_ft(caption = "Table 1")
  ft2 <- make_ft(caption = "Table 2")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(list(ft1, ft2), preview = TRUE)
  expect_null(result)
})

# S3 dispatch --------------------------------------------------------------

test_that("S3 method is registered for flextable", {
  expect_true(is.function(getS3method("export_tfl", "flextable")))
})

test_that("export_tfl dispatches to flextable method", {
  ft <- make_ft()
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  # Should not error — dispatches to export_tfl.flextable
  expect_no_error(export_tfl(ft, preview = TRUE))
})

# Pagination end-to-end ---------------------------------------------------

test_that("tall flextable paginates in export_tfl", {
  big_ft <- flextable::flextable(mtcars[, 1:4])
  big_ft <- flextable::set_caption(big_ft, "All mtcars")
  big_ft <- flextable::add_footer_lines(big_ft, "Source: datasets package.")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  result <- export_tfl(big_ft, file = tmp, pg_height = 5,
                       min_content_height = grid::unit(1, "inches"))
  expect_true(file.exists(tmp))
})

# Preserved features -------------------------------------------------------

test_that("borders are preserved in grob output", {
  ft <- flextable::flextable(head(mtcars, 3))
  ft <- flextable::border_outer(ft)
  grob <- writetfl:::.flextable_to_grob(ft, content_w = 10)
  expect_true(inherits(grob, "flextableGrob"))
})

test_that("merged cells are preserved in grob output", {
  ft <- flextable::flextable(head(mtcars[, 1:3], 4))
  ft <- flextable::merge_v(ft, j = 1)
  grob <- writetfl:::.flextable_to_grob(ft, content_w = 10)
  expect_true(inherits(grob, "flextableGrob"))
})

test_that("theme is preserved in grob output", {
  ft <- flextable::flextable(head(mtcars, 3))
  ft <- flextable::theme_vanilla(ft)
  grob <- writetfl:::.flextable_to_grob(ft, content_w = 10)
  expect_true(inherits(grob, "flextableGrob"))
})

# Page layout elements with flextable ------------------------------------

test_that("page layout elements work with flextable", {
  ft <- make_ft(caption = "Table 1")
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  expect_no_error(export_tfl(ft, preview = TRUE,
                             header_left = "Study Report",
                             header_rule = TRUE,
                             footer_rule = TRUE))
})
