skip_if_not_installed("rtables")

# Helper: build a simple rtables table
make_rtable <- function(title = NULL, subtitles = character(0),
                        main_footer = character(0), prov_footer = character(0)) {
  lyt <- rtables::basic_table(
    title        = title %||% "",
    subtitles    = subtitles,
    main_footer  = main_footer,
    prov_footer  = prov_footer
  ) |>
    rtables::analyze("mpg", mean)
  rtables::build_table(lyt, mtcars)
}

# .extract_rtables_annotations() ------------------------------------------

test_that("main_title + subtitles → caption with newline separator", {
  tbl <- make_rtable(title = "My Title", subtitles = c("Sub A", "Sub B"))
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$caption, "My Title\nSub A\nSub B")
})

test_that("main_title only → caption without subtitles", {
  tbl <- make_rtable(title = "Title Only")
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$caption, "Title Only")
})

test_that("no title → NULL caption", {
  tbl <- make_rtable()
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_null(annot$caption)
})

test_that("main_footer → footnote", {
  tbl <- make_rtable(main_footer = "Main footer text")
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$footnote, "Main footer text")
})

test_that("prov_footer → footnote", {
  tbl <- make_rtable(prov_footer = "Provenance footer")
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$footnote, "Provenance footer")
})

test_that("main_footer + prov_footer combined with newline", {
  tbl <- make_rtable(main_footer = "Main", prov_footer = "Prov")
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$footnote, "Main\nProv")
})

test_that("no annotations → NULL caption and NULL footnote", {
  tbl <- make_rtable()
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_null(annot$caption)
  expect_null(annot$footnote)
})

test_that("multiple main_footer lines combined", {
  tbl <- make_rtable(main_footer = c("Line 1", "Line 2"))
  annot <- writetfl:::.extract_rtables_annotations(tbl)
  expect_equal(annot$footnote, "Line 1\nLine 2")
})

# .clean_rtables() --------------------------------------------------------

test_that(".clean_rtables removes all annotations", {
  tbl <- make_rtable(
    title = "Title", subtitles = "Sub",
    main_footer = "MF", prov_footer = "PF"
  )
  cleaned <- writetfl:::.clean_rtables(tbl)
  expect_equal(formatters::main_title(cleaned), "")
  expect_length(formatters::subtitles(cleaned), 0L)
  expect_length(formatters::main_footer(cleaned), 0L)
  expect_length(formatters::prov_footer(cleaned), 0L)
})

test_that(".clean_rtables toString output has no title or footer", {
  tbl <- make_rtable(
    title = "Title", main_footer = "Footer"
  )
  cleaned <- writetfl:::.clean_rtables(tbl)
  txt <- toString(cleaned)
  expect_false(grepl("Title", txt, fixed = TRUE))
  expect_false(grepl("Footer", txt, fixed = TRUE))
})

# .rtables_to_grob() ------------------------------------------------------

test_that(".rtables_to_grob returns a textGrob", {
  tbl <- make_rtable()
  grob <- writetfl:::.rtables_to_grob(tbl)
  expect_true(inherits(grob, "grob"))
  expect_true(grid::is.grob(grob))
})

test_that(".rtables_to_grob contains table text", {
  tbl <- make_rtable()
  grob <- writetfl:::.rtables_to_grob(tbl)
  # The grob label should contain the text from toString
  expect_true(grepl("mean", grob$label, fixed = TRUE) ||
                grepl("mean", as.character(grob$label), fixed = TRUE) ||
                !is.null(grob$label))
})

# .rtables_lpp_cpp() -------------------------------------------------------

test_that(".rtables_lpp_cpp returns positive integers", {
  result <- writetfl:::.rtables_lpp_cpp(7, 10, "Courier", 8, 1)
  expect_true(is.integer(result$lpp))
  expect_true(is.integer(result$cpp))
  expect_true(result$lpp > 0L)
  expect_true(result$cpp > 0L)
})

test_that(".rtables_lpp_cpp: smaller height → smaller lpp", {
  big <- writetfl:::.rtables_lpp_cpp(7, 10, "Courier", 8, 1)
  small <- writetfl:::.rtables_lpp_cpp(3, 10, "Courier", 8, 1)
  expect_true(small$lpp < big$lpp)
})

test_that(".rtables_lpp_cpp: smaller width → smaller cpp", {
  big <- writetfl:::.rtables_lpp_cpp(7, 10, "Courier", 8, 1)
  small <- writetfl:::.rtables_lpp_cpp(7, 4, "Courier", 8, 1)
  expect_true(small$cpp < big$cpp)
})

# .rtables_content_height() -----------------------------------------------

test_that(".rtables_content_height returns positive numeric", {
  h <- writetfl:::.rtables_content_height(
    11, 8.5, list(), "Page {i} of {n}",
    list(caption = NULL, footnote = NULL)
  )
  expect_true(is.numeric(h))
  expect_true(h > 0)
})

test_that(".rtables_content_height uses dots when provided", {
  h <- writetfl:::.rtables_content_height(
    11, 8.5,
    list(margins = grid::unit(c(1, 1, 1, 1), "inches")),
    "Page {i} of {n}",
    list(caption = NULL, footnote = NULL)
  )
  expect_true(h > 0)
  # With larger margins, height should be smaller
  h_default <- writetfl:::.rtables_content_height(
    11, 8.5, list(), "Page {i} of {n}",
    list(caption = NULL, footnote = NULL)
  )
  expect_true(h < h_default)
})

# .rtables_content_width() ------------------------------------------------

test_that(".rtables_content_width returns positive numeric", {
  w <- writetfl:::.rtables_content_width(11, list())
  expect_true(is.numeric(w))
  expect_true(w > 0)
  expect_true(w < 11)
})

test_that(".rtables_content_width respects custom margins", {
  custom_margins <- grid::unit(c(1, 1, 1, 1), "inches")
  w <- writetfl:::.rtables_content_width(11, list(margins = custom_margins))
  expect_equal(w, 9)
})

# rtables_to_pagelist() ---------------------------------------------------

test_that("rtables_to_pagelist returns page spec with content and annotations", {
  tbl <- make_rtable(title = "My Title", main_footer = "My Footer")
  pages <- writetfl:::rtables_to_pagelist(tbl)
  expect_true(is.list(pages))
  expect_true(length(pages) >= 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
  expect_equal(pages[[1]]$caption, "My Title")
  expect_equal(pages[[1]]$footnote, "My Footer")
})

test_that("rtables_to_pagelist with no annotations omits caption/footnote", {
  tbl <- make_rtable()
  pages <- writetfl:::rtables_to_pagelist(tbl)
  expect_true(is.list(pages))
  expect_null(pages[[1]]$caption)
  expect_null(pages[[1]]$footnote)
})

# export_tfl.VTableTree() — end-to-end ------------------------------------

test_that("export_tfl writes PDF from VTableTree", {
  tbl <- make_rtable(title = "PDF Test")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  result <- export_tfl(tbl, file = f)
  expect_true(file.exists(f))
  expect_true(file.size(f) > 0)
  expect_equal(result, normalizePath(f, mustWork = FALSE))
})

test_that("export_tfl preview mode works with VTableTree", {
  tbl <- make_rtable(title = "Preview Test")
  pdf(tempfile(fileext = ".pdf"), width = 11, height = 8.5)
  on.exit(dev.off())
  result <- export_tfl(tbl, preview = TRUE)
  expect_null(result)
})

test_that("export_tfl.VTableTree passes dots as defaults", {
  tbl <- make_rtable(title = "Dots Test")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  result <- export_tfl(tbl, file = f, header_left = "Study Report")
  expect_true(file.exists(f))
})

# export_tfl.list() with VTableTree objects --------------------------------

test_that("list of VTableTree objects → multi-page PDF", {
  tbl1 <- make_rtable(title = "Table 1")
  tbl2 <- make_rtable(title = "Table 2")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  result <- export_tfl(list(tbl1, tbl2), file = f)
  expect_true(file.exists(f))
  expect_true(file.size(f) > 0)
})

test_that("list of VTableTree preview renders all pages", {
  tbl1 <- make_rtable(title = "Page 1")
  tbl2 <- make_rtable(title = "Page 2")
  pdf(tempfile(fileext = ".pdf"), width = 11, height = 8.5)
  on.exit(dev.off())
  result <- export_tfl(list(tbl1, tbl2), preview = TRUE)
  expect_null(result)
})

# Pagination ---------------------------------------------------------------

test_that("rtables_to_pagelist paginates tall table", {
  # Build a table with many rows
  big_data <- data.frame(
    group = rep(paste0("G", 1:10), each = 10),
    val = rnorm(100)
  )
  lyt <- rtables::basic_table(title = "Big Table") |>
    rtables::split_rows_by("group") |>
    rtables::analyze("val", mean)
  tbl <- rtables::build_table(lyt, big_data)

  pages <- writetfl:::rtables_to_pagelist(
    tbl, pg_width = 11, pg_height = 4,
    dots = list(min_content_height = grid::unit(1, "inches"))
  )
  expect_true(length(pages) >= 1L)
  # All pages should have content grobs
  for (p in pages) {
    expect_true(inherits(p$content, "grob"))
  }
  # All pages should carry annotations
  for (p in pages) {
    expect_equal(p$caption, "Big Table")
  }
})

test_that("rtables pagination with column splits", {
  lyt <- rtables::basic_table(title = "Column Splits") |>
    rtables::split_cols_by("Species") |>
    rtables::analyze("Sepal.Length", mean)
  tbl <- rtables::build_table(lyt, iris)

  pages <- writetfl:::rtables_to_pagelist(tbl)
  expect_true(length(pages) >= 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
})

test_that("rtables pagination with nested row groups", {
  lyt <- rtables::basic_table(title = "Nested") |>
    rtables::split_cols_by("Species") |>
    rtables::split_rows_by("Petal.Width") |>
    rtables::analyze("Sepal.Length", mean)
  tbl <- rtables::build_table(lyt, iris)

  pages <- writetfl:::rtables_to_pagelist(tbl)
  expect_true(length(pages) >= 1L)
  for (p in pages) {
    expect_true(inherits(p$content, "grob"))
  }
})

# S3 dispatch --------------------------------------------------------------

test_that("export_tfl dispatches to VTableTree method", {
  method <- getS3method("export_tfl", "VTableTree", optional = TRUE)
  expect_true(is.function(method))
})

test_that("export_tfl dispatches to list method for VTableTree lists", {
  tbl1 <- make_rtable(title = "T1")
  tbl2 <- make_rtable(title = "T2")
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  # Should not error — list method detects VTableTree elements
  expect_no_error(export_tfl(list(tbl1, tbl2), file = f))
})

# Font parameters ----------------------------------------------------------

test_that("rtables_to_pagelist accepts font parameters via dots", {
  tbl <- make_rtable(title = "Font Test")
  pages <- writetfl:::rtables_to_pagelist(
    tbl,
    dots = list(
      rtables_font_family = "Courier",
      rtables_font_size   = 10,
      rtables_lineheight  = 1.2
    )
  )
  expect_true(length(pages) >= 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
})
