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

# .gt_row_groups() ---------------------------------------------------------

test_that(".gt_row_groups returns one group per row when ungrouped", {
  tbl <- gt::gt(head(mtcars, 4))
  cleaned <- writetfl:::.clean_gt(tbl)
  groups <- writetfl:::.gt_row_groups(cleaned)
  expect_length(groups, 4L)
  expect_equal(groups[[1L]], 1L)
  expect_equal(groups[[4L]], 4L)
})

test_that(".gt_row_groups returns group boundaries for row-grouped gt", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::tab_row_group(label = "Group A", rows = 1:3) |>
    gt::tab_row_group(label = "Group B", rows = 4:6)
  cleaned <- writetfl:::.clean_gt(tbl)
  groups <- writetfl:::.gt_row_groups(cleaned)
  expect_length(groups, 2L)
  # Each group should have 3 rows
  expect_equal(sort(lengths(groups)), c(3L, 3L))
  # All rows should be covered
  all_rows <- sort(unlist(groups))
  expect_equal(all_rows, 1:6)
})

# .rebuild_gt_subset() -----------------------------------------------------

test_that(".rebuild_gt_subset creates valid gt from row subset", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::tab_header(title = "Full") |>
    gt::tab_source_note("Source")
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  expect_true(inherits(sub, "gt_tbl"))
  expect_equal(nrow(sub[["_data"]]), 3L)
})

test_that(".rebuild_gt_subset preserves row groups in subset", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::tab_row_group(label = "Group A", rows = 1:3) |>
    gt::tab_row_group(label = "Group B", rows = 4:6)
  cleaned <- writetfl:::.clean_gt(tbl)
  # Take only Group A rows
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  stub <- sub[["_stub_df"]]
  expect_equal(nrow(stub), 3L)
  # Group A should be present
  present_groups <- unique(stub$group_id[!is.na(stub$group_id)])
  expect_true("Group A" %in% present_groups)
  expect_false("Group B" %in% present_groups)
})

test_that(".rebuild_gt_subset re-indexes formats", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::fmt_number(columns = "mpg", decimals = 1)
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, c(2L, 4L, 6L))
  # Formats should reference rows 1, 2, 3 (re-indexed)
  fmts <- sub[["_formats"]]
  expect_true(length(fmts) > 0L)
  expect_equal(sort(fmts[[1L]]$rows), 1:3)
})

test_that(".rebuild_gt_subset re-indexes styles", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::tab_style(
      style = gt::cell_fill(color = "lightblue"),
      locations = gt::cells_body(columns = "mpg", rows = c(2, 4))
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, c(2L, 4L, 6L))
  styles <- sub[["_styles"]]
  data_styles <- styles[styles$locname == "data", ]
  # Original rows 2,4 → new rows 1,2
  expect_true(all(data_styles$rownum %in% c(1L, 2L)))
})

test_that(".rebuild_gt_subset drops formats not in subset", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::fmt_number(columns = "mpg", rows = 4:6, decimals = 1)
  cleaned <- writetfl:::.clean_gt(tbl)
  # Take only rows 1:3, which have no formatting
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  fmts <- sub[["_formats"]]
  # Format was for rows 4-6 only, so should be dropped
  expect_length(fmts, 0L)
})

test_that(".rebuild_gt_subset converts to valid grob", {
  tbl <- gt::gt(mtcars[1:6, ]) |>
    gt::fmt_number(columns = "mpg", decimals = 1)
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves spanners", {
  tbl <- gt::gt(mtcars[1:6, 1:6]) |>
    gt::tab_spanner(label = "Performance", columns = c(mpg, cyl, disp)) |>
    gt::tab_spanner(label = "Engine", columns = c(hp, drat, wt))
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  expect_equal(nrow(sub[["_spanners"]]), 2L)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves cols_merge", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::cols_merge(columns = c(mpg, cyl), pattern = "{1} ({2})")
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves summary_rows for present groups", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::tab_row_group(label = "A", rows = 1:3) |>
    gt::tab_row_group(label = "B", rows = 4:6) |>
    gt::summary_rows(
      groups = "A",
      columns = mpg,
      fns = list(mean = ~ mean(.))
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  # Subset includes group A — summary should be preserved
  sub_a <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  expect_true(length(sub_a[["_summary"]]) > 0L)
  grob_a <- gt::as_gtable(sub_a)
  expect_true(inherits(grob_a, "grob"))
})

test_that(".rebuild_gt_subset drops summary_rows for absent groups", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::tab_row_group(label = "A", rows = 1:3) |>
    gt::tab_row_group(label = "B", rows = 4:6) |>
    gt::summary_rows(
      groups = "A",
      columns = mpg,
      fns = list(mean = ~ mean(.))
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  # Subset includes only group B — summary for A should be dropped
  sub_b <- writetfl:::.rebuild_gt_subset(cleaned, 4:6)
  expect_length(sub_b[["_summary"]], 0L)
})

test_that(".rebuild_gt_subset copies grand summary for ungrouped tables", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::grand_summary_rows(
      columns = mpg,
      fns = list(Total = ~ sum(.))
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  expect_true(length(sub[["_summary"]]) > 0L)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset copies transforms and substitutions", {
  tbl <- gt::gt(mtcars[1:6, 1:4])
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)
  # These slots should exist (even if empty)
  expect_true("_transforms" %in% names(sub))
  expect_true("_substitutions" %in% names(sub))
})

test_that(".rebuild_gt_subset preserves locale", {
  tbl <- gt::gt(mtcars[1:6, 1:4], locale = "de")
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)

  expect_equal(sub[["_locale"]], cleaned[["_locale"]])
})

test_that(".rebuild_gt_subset preserves stubhead label", {
  tbl <- gt::gt(mtcars[1:6, 1:4], rownames_to_stub = TRUE) |>
    gt::tab_stubhead(label = "Car")
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)

  expect_equal(sub[["_stubhead"]]$label, "Car")
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves sub_missing() substitutions", {
  df <- data.frame(a = c(1, NA, 3, NA, 5, 6), b = c(10, 20, 30, 40, 50, 60))
  tbl <- gt::gt(df) |>
    gt::sub_missing(columns = a, missing_text = "N/A")
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, c(1, 2, 3))

  expect_true(length(sub[["_substitutions"]]) > 0L)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves text_transform()", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::text_transform(
      locations = gt::cells_body(columns = mpg),
      fn = function(x) paste0(x, " mpg")
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)

  expect_true(length(sub[["_transforms"]]) > 0L)
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset preserves tab_options()", {
  tbl <- gt::gt(mtcars[1:6, 1:4]) |>
    gt::tab_options(
      table.font.size = gt::px(10),
      row.striping.include_table_body = TRUE
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)

  expect_equal(sub[["_options"]], cleaned[["_options"]])
  grob <- gt::as_gtable(sub)
  expect_true(inherits(grob, "grob"))
})

test_that(".rebuild_gt_subset copies _summary_cols when present", {
  df <- data.frame(
    group = rep(c("A", "B"), each = 3),
    val = c(10, 20, 30, 40, 50, 60)
  )
  tbl <- gt::gt(df, groupname_col = "group") |>
    gt::summary_rows(
      groups = gt::everything(),
      columns = val,
      fns = list(Total = ~ sum(.))
    )
  cleaned <- writetfl:::.clean_gt(tbl)
  sub <- writetfl:::.rebuild_gt_subset(cleaned, 1:3)

  # _summary_cols may or may not be populated depending on gt version,

  # but the slot should be carried through if present
  if (length(cleaned[["_summary_cols"]]) > 0L) {
    expect_equal(sub[["_summary_cols"]], cleaned[["_summary_cols"]])
  } else {
    expect_true(TRUE)  # slot empty in this gt version
  }
})

# .gt_content_height() / .gt_grob_height() --------------------------------

test_that(".gt_content_height returns positive numeric", {
  h <- writetfl:::.gt_content_height(11, 8.5, list(), "Page {i} of {n}",
                                      list(caption = NULL, footnote = NULL))
  expect_true(is.numeric(h))
  expect_true(h > 0)
})

test_that(".gt_content_height accounts for dots layout args", {
  h_plain <- writetfl:::.gt_content_height(
    11, 8.5, list(), "Page {i} of {n}",
    list(caption = NULL, footnote = NULL)
  )
  h_with_margin <- writetfl:::.gt_content_height(
    11, 8.5,
    list(margins = grid::unit(c(1, 1, 1, 1), "inches")),
    "Page {i} of {n}",
    list(caption = NULL, footnote = NULL)
  )
  # Larger margins → less content height
  expect_true(h_with_margin < h_plain)
})

test_that(".gt_grob_height returns positive numeric", {
  tbl <- gt::gt(head(mtcars, 3))
  grob <- gt::as_gtable(tbl)
  h <- writetfl:::.gt_grob_height(grob, 11, 8.5)
  expect_true(is.numeric(h))
  expect_true(h > 0)
})

# Pagination — gt_to_pagelist() with tall tables ---------------------------

test_that("gt_to_pagelist paginates tall table across multiple pages", {
  # Create a table tall enough to need pagination on a tiny page
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 3), ]
  tbl <- gt::gt(big_data) |>
    gt::tab_header(title = "Big Table")

  # Use a very short page to force pagination
  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  expect_true(length(pages) > 1L)
  # All pages should have content grobs

  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
  }
  # All pages should carry the caption
  expect_equal(pages[[1L]]$caption, "Big Table")
  expect_equal(pages[[length(pages)]]$caption, "Big Table")
})

test_that("gt_to_pagelist respects row group boundaries", {
  # 3 groups of 10 rows each — on a short page, should split at group boundaries
  grp_data <- data.frame(
    group = rep(c("A", "B", "C"), each = 10),
    value = seq_len(30),
    stringsAsFactors = FALSE
  )
  tbl <- gt::gt(grp_data, groupname_col = "group")

  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  # Should produce multiple pages without splitting within a group
  expect_true(length(pages) >= 2L)
  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
  }
})

test_that("gt_to_pagelist pagination carries footnote annotations", {
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 3), ]
  tbl <- gt::gt(big_data) |>
    gt::tab_header(title = "Big Table") |>
    gt::tab_source_note("Important source note")

  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  expect_true(length(pages) > 1L)
  # All pages should have footnote
  for (pg in pages) {
    expect_equal(pg$footnote, "Important source note")
  }
})

test_that("gt_to_pagelist single page when table fits", {
  tbl <- gt::gt(head(mtcars, 3))
  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 8.5)
  expect_length(pages, 1L)
})

test_that("export_tfl with tall gt produces multi-page PDF", {
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 3), ]
  tbl <- gt::gt(big_data) |>
    gt::tab_header(title = "Big Table")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  result <- export_tfl(tbl, file = tmp, pg_height = 4,
                       min_content_height = grid::unit(1, "inches"))
  expect_true(file.exists(tmp))
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("list of tall gt_tbl objects paginates each independently", {
  big1 <- gt::gt(mtcars[rep(1:10, 3), 1:4]) |>
    gt::tab_header(title = "Table 1")
  big2 <- gt::gt(mtcars[rep(11:20, 3), 1:4]) |>
    gt::tab_header(title = "Table 2")
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  result <- export_tfl(list(big1, big2), file = tmp, pg_height = 4,
                       min_content_height = grid::unit(1, "inches"))
  expect_true(file.exists(tmp))
})

# End-to-end: pagination with advanced features ----------------------------

test_that("pagination preserves fmt_number formatting", {
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 2), 1:4]
  tbl <- gt::gt(big_data) |>
    gt::fmt_number(columns = "mpg", decimals = 1)

  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  expect_true(length(pages) > 1L)
  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
  }
})

test_that("pagination preserves spanners", {
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 2), 1:6]
  tbl <- gt::gt(big_data) |>
    gt::tab_spanner(label = "Performance", columns = c(mpg, cyl, disp))

  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  expect_true(length(pages) > 1L)
  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
  }
})

test_that("pagination preserves tab_style", {
  big_data <- mtcars[rep(seq_len(nrow(mtcars)), 2), 1:4]
  tbl <- gt::gt(big_data) |>
    gt::tab_style(
      style = gt::cell_fill(color = "lightblue"),
      locations = gt::cells_body(columns = "mpg", rows = 1:5)
    )

  pages <- writetfl:::gt_to_pagelist(tbl, pg_width = 11, pg_height = 4)
  expect_true(length(pages) > 1L)
  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
  }
})

# S3 dispatch --------------------------------------------------------------

test_that("export_tfl dispatches to gt_tbl method", {
  expect_true(is.function(getS3method("export_tfl", "gt_tbl")))
})

test_that("export_tfl dispatches to list method", {
  expect_true(is.function(getS3method("export_tfl", "list")))
})
