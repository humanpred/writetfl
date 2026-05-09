# test-row_span.R — HTML-rowspan-style flow for multi-line group labels
#
# Issue #29: a multi-line value in a group column should not force its row to
# be tall enough to fit all label lines.  Instead, the label should be
# allowed to flow into the suppressed (blanked) cells in the rows below it,
# the same way HTML <td rowspan="N"> reserves a single cell that visually
# spans N rows.
#
# Tests here exercise three layers:
#   * .compute_page_row_heights()  — the core algorithm (synthetic inputs)
#   * paginate_rows()              — span-aware pagination (per-page recompute)
#   * export_tfl()                 — end-to-end rendering smoke tests
#
# The synthetic-input tests deliberately bypass grid::stringHeight() so the
# expected heights are exact rather than device-dependent.

# ---- helpers ---------------------------------------------------------------

# Build a minimal resolved_cols list for .compute_page_row_heights().
.spec <- function(col, is_group_col = FALSE) {
  list(col = col, is_group_col = is_group_col)
}

# ---- .compute_page_row_heights() -------------------------------------------

test_that("two-row span fits in available height; no row grows", {
  # data: A is a 2-line group label spanning two rows, B is single-line.
  # cell_h_mat: A column heights = c(2, 0); B column heights = c(1, 1).
  # The 0 in A row 2 is irrelevant (cell is suppressed); algorithm reads only
  # the start-of-span value.
  cell_h_mat <- matrix(c(2, 0,    # column A
                         1, 1),   # column B
                       nrow = 2, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  suppress_mat  <- matrix(c(FALSE, TRUE), nrow = 2, ncol = 1,
                          dimnames = list(NULL, "A"))

  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:2, resolved_cols,
    group_vars = "A", suppress_mat = suppress_mat
  )
  # Both rows stay at 1 (the non-group-cell height). Label fits in span = 2.
  expect_equal(row_h, c(1, 1))
})

test_that("single-row span grows to fit the multi-line label", {
  cell_h_mat <- matrix(c(2,    # A
                         1),   # B
                       nrow = 1, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  suppress_mat  <- matrix(FALSE, nrow = 1, ncol = 1,
                          dimnames = list(NULL, "A"))

  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1L, resolved_cols,
    group_vars = "A", suppress_mat = suppress_mat
  )
  # Available = 1, label = 2 → grow to 2.
  expect_equal(row_h, 2)
})

test_that("nested groups: inner span absorbed first, outer borrows remainder", {
  # Three rows, two group columns A (outer) and B (inner).
  # A has label height 2 over all 3 rows (one big span).
  # B has label height 2 over rows 1-2, then a new value at row 3.
  # Non-group column C is 1 line per row.
  # Expected: inner span (B 1-2) sees label=2 vs avail=2 → no grow.
  # Outer span (A 1-3) sees label=2 vs avail=3 → no grow.
  cell_h_mat <- matrix(c(2, 0, 0,    # A
                         2, 0, 1,    # B
                         1, 1, 1),   # C
                       nrow = 3, byrow = FALSE)
  resolved_cols <- list(
    .spec("A", is_group_col = TRUE),
    .spec("B", is_group_col = TRUE),
    .spec("C")
  )
  suppress_mat <- matrix(c(FALSE, TRUE,  TRUE,
                           FALSE, TRUE,  FALSE),
                         nrow = 3, ncol = 2,
                         dimnames = list(NULL, c("A", "B")))
  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:3, resolved_cols,
    group_vars = c("A", "B"), suppress_mat = suppress_mat
  )
  expect_equal(row_h, c(1, 1, 1))
})

test_that("nested groups: inner growth feeds outer span availability", {
  # A is 5 lines tall over 3 rows, B has a 4-line label on its own (1 span).
  # Non-group column C is 1 line per row.
  # Inner pass: B span = rows 1-3, label = 4 vs avail = 3 → grow row 1 by 1.
  #   row_h becomes c(2, 1, 1).
  # Outer pass: A span = rows 1-3, label = 5 vs avail = 4 → grow row 1 by 1.
  #   row_h becomes c(3, 1, 1).
  cell_h_mat <- matrix(c(5, 0, 0,    # A
                         4, 0, 0,    # B
                         1, 1, 1),   # C
                       nrow = 3, byrow = FALSE)
  resolved_cols <- list(
    .spec("A", is_group_col = TRUE),
    .spec("B", is_group_col = TRUE),
    .spec("C")
  )
  suppress_mat <- matrix(c(FALSE, TRUE,  TRUE,
                           FALSE, TRUE,  TRUE),
                         nrow = 3, ncol = 2,
                         dimnames = list(NULL, c("A", "B")))
  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:3, resolved_cols,
    group_vars = c("A", "B"), suppress_mat = suppress_mat
  )
  expect_equal(row_h, c(3, 1, 1))
})

test_that("suppress_mat = NULL falls back to per-row max over all columns", {
  # When suppression is disabled, every cell is rendered, so the row needs to
  # accommodate its tallest cell — including the group cell.
  cell_h_mat <- matrix(c(2, 2,    # A (group, but not suppressed)
                         1, 1),   # B
                       nrow = 2, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:2, resolved_cols,
    group_vars = "A", suppress_mat = NULL
  )
  expect_equal(row_h, c(2, 2))
})

test_that("no group_vars degenerates to per-row max", {
  cell_h_mat <- matrix(c(3, 1,    # A
                         1, 4),   # B
                       nrow = 2, byrow = FALSE)
  resolved_cols <- list(.spec("A"), .spec("B"))
  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:2, resolved_cols,
    group_vars = character(0L), suppress_mat = NULL
  )
  expect_equal(row_h, c(3, 4))
})

test_that("zero-row page returns numeric(0)", {
  expect_equal(
    writetfl:::.compute_page_row_heights(
      matrix(numeric(0L), nrow = 0L, ncol = 2L),
      page_rows = integer(0L),
      resolved_cols = list(.spec("A", is_group_col = TRUE), .spec("B")),
      group_vars = "A", suppress_mat = NULL
    ),
    numeric(0L)
  )
})

# ---- paginate_rows() — span-aware fit + orphan handling --------------------

test_that("3-row group with 3-line label fits on one page (free-row)", {
  # Property (a) from the design: adding a row to an open span can leave the
  # page total unchanged.  3-row group, label = 3 lines, non-group = 1 line.
  # Per-row independent sum would be 3 + 1 + 1 = 5 lines.  Span-aware total
  # is max(3, 3) = 3 lines, so the page holds all three rows in a 3-line
  # content height.
  #
  # Note: cell_h_mat carries the *natural* cell height regardless of
  # suppression — pagination's per-page recompute reads the current span
  # start row's cell value, which may differ between pages if the same group
  # is split across pages (label re-shown on a new page).
  data <- data.frame(grp = rep("L1\nL2\nL3", 3L),
                     val = c("a", "b", "c"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(3, 3, 3,    # grp (label = 3 lines, regardless of suppression)
                         1, 1, 1),   # val
                       nrow = 3, byrow = FALSE)
  resolved_cols <- list(.spec("grp", is_group_col = TRUE), .spec("val"))

  pages <- writetfl:::paginate_rows(
    data, cell_h_mat, resolved_cols,
    group_vars = "grp",
    cont_row_h = 0, header_row_h = 0,
    content_height_in = 3,
    row_cont_msg = c("(continued above)", "(continued below)"),
    group_rule = FALSE,
    simplify_rowspan = TRUE
  )
  expect_length(pages, 1L)
  expect_equal(pages[[1L]]$rows, 1:3)
  # Each row is 1 line; the label flows.
  expect_equal(pages[[1L]]$row_heights_in, c(1, 1, 1))
})

test_that("group orphan: lone first-row on a page grows to fit full label", {
  # Property (b): when the rest of a group is pushed to the next page, the
  # row that lands alone on the new page must be tall enough for the full
  # (re-shown) label by itself.
  #
  # Setup: 4-row group with label = 4 lines, val = 1 line for rows 1-3 and
  # 2 lines for row 4.  Adding row 4 to the [1..3] page would push the total
  # over the budget (because val = 2), so row 4 gets flushed to its own page
  # where, as a single-row span, it must grow to fit the 4-line label.
  data <- data.frame(grp = rep("L1\nL2\nL3\nL4", 4L),
                     val = c("a", "b", "c", "d\ne"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(4, 4, 4, 4,    # grp
                         1, 1, 1, 2),   # val (row 4 is 2 lines)
                       nrow = 4, byrow = FALSE)
  resolved_cols <- list(.spec("grp", is_group_col = TRUE), .spec("val"))

  warns <- character(0)
  pages <- withCallingHandlers(
    writetfl:::paginate_rows(
      data, cell_h_mat, resolved_cols,
      group_vars = "grp",
      cont_row_h = 1, header_row_h = 0,
      content_height_in = 5,
      row_cont_msg = c("(continued above)", "(continued below)"),
      group_rule = FALSE,
      simplify_rowspan = TRUE
    ),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning")
    }
  )
  # The group split must trigger the (continued) warning.
  expect_true(any(grepl("continued", warns)))
  # Two pages: rows 1-3 on page 1 (label spans them with deficit on row 1),
  # row 4 alone on page 2 with full label height.
  expect_length(pages, 2L)
  expect_equal(pages[[1L]]$rows, 1:3)
  # Page 1: span = [1,2,3], avail = 3, label = 4 → deficit 1 on row 1.
  expect_equal(pages[[1L]]$row_heights_in, c(2, 1, 1))
  expect_equal(pages[[2L]]$rows, 4L)
  # Page 2 orphan: single-row span re-shows the 4-line label.
  expect_equal(pages[[2L]]$row_heights_in, 4)
})

test_that("pagination reset per page: re-shown label on next page sized correctly", {
  # Same setup as the orphan test but framed around "the same data renders
  # at different row heights on different pages because suppression resets
  # at every page boundary".  Page 2's row 4 must be tall enough for the
  # re-shown label (= 4 lines) even though it was 1 line on page 1's matrix.
  data <- data.frame(grp = rep("L1\nL2\nL3\nL4", 4L),
                     val = c("a", "b", "c", "d\ne"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(4, 4, 4, 4,
                         1, 1, 1, 2),
                       nrow = 4, byrow = FALSE)
  resolved_cols <- list(.spec("grp", is_group_col = TRUE), .spec("val"))

  pages <- suppressWarnings(writetfl:::paginate_rows(
    data, cell_h_mat, resolved_cols,
    group_vars = "grp",
    cont_row_h = 1, header_row_h = 0,
    content_height_in = 5,
    row_cont_msg = c("(continued above)", "(continued below)"),
    group_rule = FALSE,
    simplify_rowspan = TRUE
  ))
  # Page 2 orphan: row 4 alone at 4 lines (label height).  This is the
  # "same row may render differently on different pages" property.
  expect_equal(pages[[2L]]$row_heights_in, 4)
})

test_that("paginate_rows defaults to historical per-row max (simplify_rowspan = FALSE)", {
  # Without the opt-in, the same input that produces flowing rows of 1 line
  # under TRUE produces fat rows of label height under the historical layout.
  data <- data.frame(grp = rep("L1\nL2\nL3", 3L),
                     val = c("a", "b", "c"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(3, 3, 3,    # grp
                         1, 1, 1),   # val
                       nrow = 3, byrow = FALSE)
  resolved_cols <- list(.spec("grp", is_group_col = TRUE), .spec("val"))

  pages <- writetfl:::paginate_rows(
    data, cell_h_mat, resolved_cols,
    group_vars = "grp",
    cont_row_h = 0, header_row_h = 0,
    content_height_in = 9,   # generous so all rows fit
    row_cont_msg = c("(continued above)", "(continued below)"),
    group_rule = FALSE
    # simplify_rowspan defaults to FALSE
  )
  # Historical: each row's height = max over ALL cells (incl. group label).
  expect_equal(pages[[1L]]$row_heights_in, c(3, 3, 3))
})

# ---- end-to-end via export_tfl() -------------------------------------------

test_that("end-to-end: simplify_rowspan = TRUE renders user's example without error", {
  # The user's exact example from issue #29:
  #   page 1: A = c("B\nC", "B\nC"), D = c("E", "F")
  #   page 2 (after suppression reset): A = "B\nC", D = "F"
  df <- dplyr::group_by(
    data.frame(A = rep("B\nC", 3L),
               D = c("E", "F", "G"),
               stringsAsFactors = FALSE),
    A
  )
  tbl <- tfl_table(df, simplify_rowspan = TRUE)
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(
    suppressWarnings(  # the deliberate group split fires the (continued) warn
      export_tfl(tbl, file = f, pg_width = 11, pg_height = 8.5,
                 min_content_height = grid::unit(0.5, "inches"))
    )
  )
  expect_true(file.exists(f))
  expect_gt(file.info(f)$size, 0)
})

test_that("end-to-end: row_rule with simplify_rowspan = TRUE does not error in spans", {
  # Smoke test for the row-rule suppression-within-span branch.
  df <- dplyr::group_by(
    data.frame(A = c("X\nY", "X\nY", "X\nY"),
               B = c("p", "q", "r"),
               stringsAsFactors = FALSE),
    A
  )
  tbl <- tfl_table(df, row_rule = TRUE, simplify_rowspan = TRUE)
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("end-to-end: default (simplify_rowspan = FALSE) renders historically", {
  # Same input as the user-example test but without the opt-in.  The
  # default behaviour (label inflates first row of group) must keep working
  # without errors and produce a non-empty PDF.
  df <- dplyr::group_by(
    data.frame(A = rep("B\nC", 3L),
               D = c("E", "F", "G"),
               stringsAsFactors = FALSE),
    A
  )
  tbl <- tfl_table(df)   # simplify_rowspan defaults to FALSE
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f, pg_width = 11, pg_height = 8.5))
  expect_true(file.exists(f))
  expect_gt(file.info(f)$size, 0)
})
