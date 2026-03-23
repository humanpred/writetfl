skip_if_not_installed("gt")

# .extract_gt_annotations() ------------------------------------------------

test_that("title + subtitle → caption with newline separator", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_header(title = "My Title", subtitle = "My Subtitle")
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_equal(annot$caption, "My Title\nMy Subtitle")
})

test_that("title only → caption without subtitle", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_header(title = "Title Only")
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_equal(annot$caption, "Title Only")
})

test_that("no title → NULL caption", {
  tbl <- gt::gt(head(mtcars, 3))
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_null(annot$caption)
})

test_that("source notes → footnote", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_source_note("Source: Motor Trend (1974)")
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_equal(annot$footnote, "Source: Motor Trend (1974)")
})

test_that("multiple source notes are combined", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_source_note("Source 1") |>
    gt::tab_source_note("Source 2")
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_true(grepl("Source 1", annot$footnote))
  expect_true(grepl("Source 2", annot$footnote))
})

test_that("cell footnotes → footnote", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_footnote("A cell note",
                     locations = gt::cells_body(columns = mpg, rows = 1))
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_equal(annot$footnote, "A cell note")
})

test_that("source notes + cell footnotes combined", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_source_note("Source info") |>
    gt::tab_footnote("Cell note",
                     locations = gt::cells_body(columns = mpg, rows = 1))
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_true(grepl("Cell note", annot$footnote))
  expect_true(grepl("Source info", annot$footnote))
})

test_that("no annotations → NULL caption and NULL footnote", {
  tbl <- gt::gt(head(mtcars, 3))
  annot <- writetfl:::.extract_gt_annotations(tbl)
  expect_null(annot$caption)
  expect_null(annot$footnote)
})

# .clean_gt() --------------------------------------------------------------

test_that(".clean_gt removes title, source notes, and footnotes", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_header(title = "Title", subtitle = "Sub") |>
    gt::tab_source_note("Source") |>
    gt::tab_footnote("Note",
                     locations = gt::cells_body(columns = mpg, rows = 1))

  cleaned <- writetfl:::.clean_gt(tbl)
  heading <- cleaned[["_heading"]]
  # rm_header sets title/subtitle to NULL (or empty string depending on gt version)

  expect_true(is.null(heading$title) || !nzchar(heading$title))
  expect_true(is.null(heading$subtitle) || !nzchar(heading$subtitle))
  expect_length(cleaned[["_source_notes"]], 0L)
  expect_equal(nrow(cleaned[["_footnotes"]]), 0L)
})

# gt_to_pagelist() ---------------------------------------------------------

test_that("gt_to_pagelist returns page spec with content and annotations", {
  tbl <- gt::gt(head(mtcars, 3)) |>
    gt::tab_header(title = "My Table") |>
    gt::tab_source_note("Data source")

  pages <- writetfl:::gt_to_pagelist(tbl)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1L]]$content, "grob"))
  expect_equal(pages[[1L]]$caption, "My Table")
  expect_equal(pages[[1L]]$footnote, "Data source")
})

test_that("gt_to_pagelist with no annotations omits caption/footnote", {
  tbl <- gt::gt(head(mtcars, 3))
  pages <- writetfl:::gt_to_pagelist(tbl)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1L]]$content, "grob"))
  expect_null(pages[[1L]]$caption)
  expect_null(pages[[1L]]$footnote)
})

# export_tfl.gt_tbl() — end-to-end ----------------------------------------

test_that("export_tfl writes PDF from gt_tbl", {
  tbl <- gt::gt(head(mtcars, 5)) |>
    gt::tab_header(title = "Test Table")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  result <- export_tfl(tbl, file = tmp)
  expect_true(file.exists(tmp))
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("export_tfl preview mode works with gt_tbl", {
  tbl <- gt::gt(head(mtcars, 5))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(tbl, preview = TRUE)
  expect_null(result)
})

test_that("export_tfl.gt_tbl passes dots as defaults", {
  tbl <- gt::gt(head(mtcars, 3))
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  expect_no_error(
    export_tfl(tbl, file = tmp, header_left = "Global Header")
  )
})

# export_tfl.list() with gt_tbl objects ------------------------------------

test_that("list of gt_tbl objects → multi-page PDF", {
  tbl1 <- gt::gt(head(mtcars, 3)) |> gt::tab_header(title = "Table 1")
  tbl2 <- gt::gt(tail(mtcars, 3)) |> gt::tab_header(title = "Table 2")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  result <- export_tfl(list(tbl1, tbl2), file = tmp)
  expect_true(file.exists(tmp))
})

test_that("list of gt_tbl preview renders all pages", {
  tbl1 <- gt::gt(head(mtcars, 3))
  tbl2 <- gt::gt(tail(mtcars, 3))
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(list(tbl1, tbl2), preview = TRUE)
  expect_null(result)
})

test_that("list of mixed types falls through to default", {
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
    ggplot2::geom_point()
  pages <- list(
    list(content = p, caption = "Figure 1")
  )
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)
  expect_no_error(export_tfl(pages, file = tmp))
})

# S3 dispatch --------------------------------------------------------------

test_that("export_tfl dispatches to gt_tbl method", {
  expect_true(is.function(getS3method("export_tfl", "gt_tbl")))
})

test_that("export_tfl dispatches to list method", {
  expect_true(is.function(getS3method("export_tfl", "list")))
})
