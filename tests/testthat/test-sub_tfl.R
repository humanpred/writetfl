# test-sub_tfl.R — Tests for sub_tfl support (R/sub_tfl.R + integration)

library(dplyr, warn.conflicts = FALSE)

# ---------------------------------------------------------------------------
# .compute_sub_tfl_groups()
# ---------------------------------------------------------------------------

test_that("compute_sub_tfl_groups orders character columns by first appearance", {
  df <- data.frame(arm = c("B", "A", "B", "A", "C"),
                   v = 1:5, stringsAsFactors = FALSE)
  groups <- .compute_sub_tfl_groups(df, "arm")
  expect_length(groups, 3L)
  expect_equal(vapply(groups, function(g) g$values$arm, character(1)),
               c("B", "A", "C"))
  expect_equal(groups[[1L]]$row_idx, c(1L, 3L))
  expect_equal(groups[[2L]]$row_idx, c(2L, 4L))
  expect_equal(groups[[3L]]$row_idx, 5L)
})

test_that("compute_sub_tfl_groups follows factor levels (not data order)", {
  df <- data.frame(
    arm = factor(c("B", "A", "B", "A"), levels = c("A", "B", "C")),
    v   = 1:4
  )
  groups <- .compute_sub_tfl_groups(df, "arm")
  # Only A and B are present; C should be dropped.
  expect_length(groups, 2L)
  expect_equal(vapply(groups, function(g) g$values$arm, character(1)),
               c("A", "B"))
})

test_that("compute_sub_tfl_groups iterates first column outermost", {
  df <- data.frame(
    arm   = c("A", "A", "B", "B"),
    visit = c("V1", "V2", "V1", "V2"),
    v     = 1:4,
    stringsAsFactors = FALSE
  )
  groups <- .compute_sub_tfl_groups(df, c("arm", "visit"))
  expect_length(groups, 4L)
  arms   <- vapply(groups, function(g) g$values$arm,   character(1))
  visits <- vapply(groups, function(g) g$values$visit, character(1))
  expect_equal(arms,   c("A", "A", "B", "B"))
  expect_equal(visits, c("V1", "V2", "V1", "V2"))
})

test_that("compute_sub_tfl_groups skips empty Cartesian combinations", {
  df <- data.frame(
    arm   = c("A", "B"),
    visit = c("V1", "V2"),
    stringsAsFactors = FALSE
  )
  # Cartesian product is 4 combos but only 2 are present.
  groups <- .compute_sub_tfl_groups(df, c("arm", "visit"))
  expect_length(groups, 2L)
})

test_that("compute_sub_tfl_groups handles NA values by dropping them", {
  df <- data.frame(arm = c("A", NA, "A", "B"), v = 1:4,
                   stringsAsFactors = FALSE)
  groups <- .compute_sub_tfl_groups(df, "arm")
  expect_length(groups, 2L)
  # Row 2 (NA) is in no group.
  all_idx <- sort(unlist(lapply(groups, `[[`, "row_idx")))
  expect_equal(all_idx, c(1L, 3L, 4L))
})

# ---------------------------------------------------------------------------
# .resolve_col_label()
# ---------------------------------------------------------------------------

test_that("resolve_col_label uses tfl_colspec label when present", {
  tbl <- list(
    cols = list(tfl_colspec("arm", label = "Treatment Arm")),
    col_labels = c(arm = "fallback")
  )
  expect_equal(.resolve_col_label(tbl, "arm"), "Treatment Arm")
})

test_that("resolve_col_label falls back to col_labels", {
  tbl <- list(cols = NULL, col_labels = c(arm = "Arm Label"))
  expect_equal(.resolve_col_label(tbl, "arm"), "Arm Label")
})

test_that("resolve_col_label falls back to column name", {
  tbl <- list(cols = NULL, col_labels = NULL)
  expect_equal(.resolve_col_label(tbl, "arm"), "arm")
})

# ---------------------------------------------------------------------------
# .format_sub_tfl_caption() and .apply_sub_tfl_caption()
# ---------------------------------------------------------------------------

test_that("format_sub_tfl_caption produces label: value; label: value", {
  tbl <- list(cols = NULL, col_labels = NULL,
              sub_tfl_sep = ": ", sub_tfl_collapse = "; ")
  out <- .format_sub_tfl_caption(tbl, list(arm = "A", visit = "Week 4"))
  expect_equal(out, "arm: A; visit: Week 4")
})

test_that("format_sub_tfl_caption honours custom sep and collapse", {
  tbl <- list(cols = NULL, col_labels = NULL,
              sub_tfl_sep = " = ", sub_tfl_collapse = " | ")
  out <- .format_sub_tfl_caption(tbl, list(a = 1, b = 2))
  expect_equal(out, "a = 1 | b = 2")
})

test_that("format_sub_tfl_caption uses colspec label", {
  tbl <- list(cols = list(tfl_colspec("arm", label = "Treatment")),
              col_labels = NULL,
              sub_tfl_sep = ": ", sub_tfl_collapse = "; ")
  expect_equal(.format_sub_tfl_caption(tbl, list(arm = "A")),
               "Treatment: A")
})

test_that("apply_sub_tfl_caption returns suffix alone when base is NULL", {
  expect_equal(.apply_sub_tfl_caption(NULL,    "arm: A", "\n"), "arm: A")
})

test_that("apply_sub_tfl_caption joins base + prefix + suffix", {
  expect_equal(.apply_sub_tfl_caption("Table 1", "arm: A", "\n"),
               "Table 1\narm: A")
  expect_equal(.apply_sub_tfl_caption("Table 1", "arm: A", " — "),
               "Table 1 — arm: A")
})

# ---------------------------------------------------------------------------
# .strip_sub_tfl_cols()
# ---------------------------------------------------------------------------

test_that("strip_sub_tfl_cols removes entries from cols, col_widths, etc.", {
  tbl <- list(
    sub_tfl    = "arm",
    cols       = list(tfl_colspec("arm", label = "X"),
                       tfl_colspec("v",   label = "Y")),
    col_widths = list(arm = 1, v = 2),
    col_labels = c(arm = "ax", v = "vx"),
    col_align  = c(arm = "left", v = "right"),
    wrap_cols  = c("arm", "v")
  )
  out <- .strip_sub_tfl_cols(tbl)
  expect_length(out$cols, 1L)
  expect_equal(out$cols[[1L]]$col, "v")
  expect_equal(names(out$col_widths), "v")
  expect_equal(names(out$col_labels), "v")
  expect_equal(names(out$col_align),  "v")
  expect_equal(out$wrap_cols, "v")
})

test_that("strip_sub_tfl_cols sets fields to NULL when emptied", {
  tbl <- list(
    sub_tfl    = "arm",
    cols       = list(tfl_colspec("arm")),
    col_widths = list(arm = 1),
    col_labels = c(arm = "ax"),
    col_align  = NULL,
    wrap_cols  = FALSE
  )
  out <- .strip_sub_tfl_cols(tbl)
  expect_null(out$cols)
  expect_null(out$col_widths)
  expect_null(out$col_labels)
  expect_false(out$wrap_cols)
})

# ---------------------------------------------------------------------------
# tfl_table() — sub_tfl validation
# ---------------------------------------------------------------------------

test_that("tfl_table rejects non-character sub_tfl", {
  df <- data.frame(arm = "A", v = 1)
  expect_error(tfl_table(df, sub_tfl = 1), "non-empty character")
  expect_error(tfl_table(df, sub_tfl = character(0)), "non-empty character")
  expect_error(tfl_table(df, sub_tfl = NA_character_), "non-empty character")
})

test_that("tfl_table rejects sub_tfl columns not in x", {
  df <- data.frame(arm = "A", v = 1)
  expect_error(tfl_table(df, sub_tfl = "missing"), "not found in")
})

test_that("tfl_table rejects non-string sub_tfl_sep / collapse / prefix", {
  df <- data.frame(arm = "A", v = 1)
  expect_error(tfl_table(df, sub_tfl = "arm", sub_tfl_sep = 1))
  expect_error(tfl_table(df, sub_tfl = "arm", sub_tfl_collapse = c("a", "b")))
  expect_error(tfl_table(df, sub_tfl = "arm", sub_tfl_prefix = NULL))
})

test_that("tfl_table stores sub_tfl args on the object", {
  df <- data.frame(arm = "A", v = 1, stringsAsFactors = FALSE)
  tbl <- tfl_table(df, sub_tfl = "arm",
                   sub_tfl_sep = " = ", sub_tfl_collapse = " | ",
                   sub_tfl_prefix = " — ")
  expect_equal(tbl$sub_tfl, "arm")
  expect_equal(tbl$sub_tfl_sep, " = ")
  expect_equal(tbl$sub_tfl_collapse, " | ")
  expect_equal(tbl$sub_tfl_prefix, " — ")
})

# ---------------------------------------------------------------------------
# tfl_table_to_pagelist() sub_tfl branch — integration
# ---------------------------------------------------------------------------

test_that("tfl_table_to_pagelist produces one sub-table per group", {
  df <- data.frame(
    arm = c("A", "A", "B", "B"),
    lbl = c("x", "y", "x", "y"),
    val = 1:4,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(df, sub_tfl = "arm")
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list(caption = "Table 1"))
  expect_length(pages, 2L)
  expect_equal(pages[[1L]]$caption, "Table 1\narm: A")
  expect_equal(pages[[2L]]$caption, "Table 1\narm: B")
})

test_that("tfl_table_to_pagelist suffix becomes caption when global is NULL", {
  df <- data.frame(arm = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  tbl <- tfl_table(df, sub_tfl = "arm")
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  expect_equal(pages[[1L]]$caption, "arm: A")
  expect_equal(pages[[2L]]$caption, "arm: B")
})

test_that("sub_tfl drops columns from the rendered grob", {
  df <- data.frame(
    arm = c("A", "A", "B"),
    lbl = c("x", "y", "z"),
    val = 1:3,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(df, sub_tfl = "arm")
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  rendered_cols <- vapply(pages[[1L]]$content$page_cols,
                          `[[`, "", "col")
  expect_false("arm" %in% rendered_cols)
  expect_setequal(rendered_cols, c("lbl", "val"))
})

test_that("sub_tfl works when overlapping with group_vars", {
  df <- data.frame(
    arm = c("A", "A", "B", "B"),
    lbl = c("x", "y", "x", "y"),
    val = 1:4,
    stringsAsFactors = FALSE
  ) |> dplyr::group_by(arm)
  tbl <- tfl_table(df, sub_tfl = "arm")
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  expect_length(pages, 2L)
  # group_vars in rendered sub-tables must no longer include "arm".
  expect_equal(pages[[1L]]$content$tbl$group_vars, character(0))
})

test_that("sub_tfl on factor column follows factor levels", {
  df <- data.frame(
    arm = factor(c("B", "A", "C", "A"), levels = c("A", "B", "C")),
    val = 1:4
  )
  tbl <- tfl_table(df, sub_tfl = "arm")
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  caps <- vapply(pages, `[[`, "", "caption")
  expect_equal(caps, c("arm: A", "arm: B", "arm: C"))
})

test_that("sub_tfl uses tfl_colspec label in caption", {
  df <- data.frame(arm = c("A", "B"), val = 1:2, stringsAsFactors = FALSE)
  tbl <- tfl_table(
    df,
    sub_tfl = "arm",
    cols = list(tfl_colspec("arm", label = "Treatment"))
  )
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list(caption = "T1"))
  expect_equal(pages[[1L]]$caption, "T1\nTreatment: A")
})

test_that("sub_tfl with multiple columns iterates outer-first", {
  df <- data.frame(
    arm   = c("A", "A", "B", "B"),
    visit = c("V1", "V2", "V1", "V2"),
    val   = 1:4,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(df, sub_tfl = c("arm", "visit"))
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  caps <- vapply(pages, `[[`, "", "caption")
  expect_equal(caps, c("arm: A; visit: V1",
                       "arm: A; visit: V2",
                       "arm: B; visit: V1",
                       "arm: B; visit: V2"))
})

# ---------------------------------------------------------------------------
# ggtibble integration
# ---------------------------------------------------------------------------

test_that("ggtibble_to_pagelist appends sub_tfl suffix to caption", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, hp)) + ggplot2::geom_point()
  x <- tibble::tibble(
    figure  = list(p, p),
    caption = c("Cars 1", "Cars 2"),
    arm     = c("A", "B")
  )
  class(x) <- c("ggtibble", class(x))
  pages <- ggtibble_to_pagelist(x, sub_tfl = "arm")
  expect_equal(pages[[1L]]$caption, "Cars 1\narm: A")
  expect_equal(pages[[2L]]$caption, "Cars 2\narm: B")
})

test_that("ggtibble_to_pagelist suffix becomes caption when row caption absent", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, hp)) + ggplot2::geom_point()
  x <- tibble::tibble(figure = list(p, p), arm = c("A", "B"))
  class(x) <- c("ggtibble", class(x))
  pages <- ggtibble_to_pagelist(x, sub_tfl = "arm")
  expect_equal(pages[[1L]]$caption, "arm: A")
  expect_equal(pages[[2L]]$caption, "arm: B")
})

test_that("ggtibble_to_pagelist rejects unknown sub_tfl columns", {
  skip_if_not_installed("ggplot2")
  p <- ggplot2::ggplot(mtcars, ggplot2::aes(mpg, hp)) + ggplot2::geom_point()
  x <- tibble::tibble(figure = list(p), arm = "A")
  class(x) <- c("ggtibble", class(x))
  expect_error(ggtibble_to_pagelist(x, sub_tfl = "missing"), "not found")
})

# ---------------------------------------------------------------------------
# Issue #30: per-column overflow check runs *after* sub_tfl strips columns
# ---------------------------------------------------------------------------

test_that("per-column overflow check runs against the post-strip group_vars (sub_tfl ordering)", {
  # Build a table where:
  #   - group_vars are (arm, visit), with arm fixed to 6 in
  #   - data col b fixed to 3 in
  #   - pg_width = 8.5, default 0.5-in margins → content ≈ 7.5 in
  # Without sub_tfl: arm (6) + b (3) = 9 > 7.5 → group-aware overflow.
  # With sub_tfl = "arm": arm is stripped from group_vars and from the data
  # before compute_col_widths() runs, so the remaining group col 'visit' (~1 in
  # auto) + b (3) = ~4 in fits comfortably and no error is raised.
  df <- data.frame(
    arm   = c("A", "A", "B", "B"),
    visit = c("V1", "V2", "V1", "V2"),
    b     = 1:4,
    stringsAsFactors = FALSE
  )
  df <- dplyr::group_by(df, arm, visit)

  # 1. Without sub_tfl: errors as expected.
  tbl_no_sub <- tfl_table(
    df,
    cols = list(
      tfl_colspec("arm", width = grid::unit(6, "inches")),
      tfl_colspec("b",   width = grid::unit(3, "inches"))
    )
  )
  f1 <- tempfile(fileext = ".pdf"); on.exit(unlink(f1), add = TRUE)
  expect_error(
    export_tfl(tbl_no_sub, file = f1, pg_width = 8.5, pg_height = 11),
    "plus group columns"
  )

  # 2. With sub_tfl = "arm": arm is stripped by .strip_sub_tfl_cols() before
  # the per-column check runs, so the table renders without error.  Locks in
  # the ordering: per-column check happens *after* sub_tfl handling.
  tbl_sub <- tfl_table(
    df,
    cols = list(
      tfl_colspec("arm", width = grid::unit(6, "inches")),
      tfl_colspec("b",   width = grid::unit(3, "inches"))
    ),
    sub_tfl = "arm"
  )
  f2 <- tempfile(fileext = ".pdf"); on.exit(unlink(f2), add = TRUE)
  expect_no_error(
    export_tfl(tbl_sub, file = f2, pg_width = 8.5, pg_height = 11)
  )
  expect_true(file.exists(f2))
  expect_gt(file.info(f2)$size, 0)
})
