# test-row_span.R — HTML-rowspan-style flow for multi-line group labels
#
# Issue #29: a multi-line value in a group column should not force its row to
# be tall enough to fit all label lines.  Instead, the label flows into the
# suppressed (blanked) cells in the rows below it, the same way HTML
# <td rowspan="N"> reserves a single cell that visually spans N rows.
#
# This is the default behaviour whenever suppression is active
# (suppress_repeated_groups = TRUE).  When suppression is itself off, every
# group cell renders fully on every row and the per-row max over all cells
# is used (the historical layout).

# ---- helpers ---------------------------------------------------------------

# Build a minimal resolved_cols list for .compute_page_row_heights().
.spec <- function(col, is_group_col = FALSE) {
  list(col = col, is_group_col = is_group_col)
}

# ---- .compute_page_row_heights() -------------------------------------------

test_that("two-row span: label flows; both rows stay at non-group height", {
  cell_h_mat <- matrix(c(2, 2,    # column A (label = 2 lines)
                         1, 1),   # column B (1 line each)
                       nrow = 2, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  suppress_mat  <- matrix(c(FALSE, TRUE), nrow = 2, ncol = 1,
                          dimnames = list(NULL, "A"))

  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1:2, resolved_cols,
    group_vars = "A", suppress_mat = suppress_mat
  )
  expect_equal(row_h, c(1, 1))
})

test_that("single-row span: row grows to fit the multi-line label", {
  cell_h_mat <- matrix(c(2, 1), nrow = 1, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  suppress_mat  <- matrix(FALSE, nrow = 1, ncol = 1,
                          dimnames = list(NULL, "A"))

  row_h <- writetfl:::.compute_page_row_heights(
    cell_h_mat, page_rows = 1L, resolved_cols,
    group_vars = "A", suppress_mat = suppress_mat
  )
  expect_equal(row_h, 2)
})

test_that("nested groups: inner span absorbed first, outer borrows remainder", {
  cell_h_mat <- matrix(c(2, 2, 2,    # A (outer)
                         2, 2, 1,    # B (inner)
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
  cell_h_mat <- matrix(c(5, 5, 5,    # A
                         4, 4, 4,    # B
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

test_that("suppress_mat = NULL: every cell counts (per-row max over all)", {
  # Suppression disabled — every group cell renders fully on every row, so
  # the row max is taken over all cells (group and non-group alike).
  cell_h_mat <- matrix(c(2, 2,    # A (group, but rendered every row)
                         1, 1),   # B
                       nrow = 2, byrow = FALSE)
  resolved_cols <- list(.spec("A", is_group_col = TRUE), .spec("B"))
  expect_equal(
    writetfl:::.compute_page_row_heights(
      cell_h_mat, page_rows = 1:2, resolved_cols,
      group_vars = "A", suppress_mat = NULL
    ),
    c(2, 2)
  )
})

test_that("no group_vars: per-row max over all columns", {
  cell_h_mat <- matrix(c(3, 1,
                         1, 4),
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

test_that("3-row group, 3-line label fits on one page (free-row property)", {
  # Adding rows 2 and 3 to the open span doesn't change the page total —
  # the span absorbs the deficit that initially inflated row 1.
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
    content_height_in = 3,
    row_cont_msg = c("(continued above)", "(continued below)"),
    group_rule = FALSE
  )
  expect_length(pages, 1L)
  expect_equal(pages[[1L]]$rows, 1:3)
  expect_equal(pages[[1L]]$row_heights_in, c(1, 1, 1))
})

test_that("group orphan: lone first-row on a page grows to fit full label", {
  # 4-row group with label = 4 lines, val = 1 line for rows 1-3 and 2 lines
  # for row 4.  Adding row 4 to the [1..3] page would push the total over
  # the budget, so row 4 gets flushed to its own page where, as a single-
  # row span, it must grow to fit the 4-line label.
  data <- data.frame(grp = rep("L1\nL2\nL3\nL4", 4L),
                     val = c("a", "b", "c", "d\ne"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(4, 4, 4, 4,    # grp
                         1, 1, 1, 2),   # val
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
      group_rule = FALSE
    ),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("continued", warns)))
  expect_length(pages, 2L)
  expect_equal(pages[[1L]]$rows, 1:3)
  expect_equal(pages[[1L]]$row_heights_in, c(2, 1, 1))
  expect_equal(pages[[2L]]$rows, 4L)
  expect_equal(pages[[2L]]$row_heights_in, 4)
})

test_that("pagination reset per page: orphan re-shows the label and grows", {
  # The same data renders at different row heights on different pages
  # because suppression resets at every page boundary.
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
    group_rule = FALSE
  ))
  expect_equal(pages[[2L]]$row_heights_in, 4)
})

test_that("paginate_rows: suppress_repeated_groups = FALSE inflates every row", {
  # If suppression is itself disabled, every group cell renders on every
  # row, so each row inflates to label height.  This is the strict
  # historical layout and the only way to opt out of the rowspan flow.
  data <- data.frame(grp = rep("L1\nL2\nL3", 3L),
                     val = c("a", "b", "c"),
                     stringsAsFactors = FALSE)
  cell_h_mat <- matrix(c(3, 3, 3,
                         1, 1, 1),
                       nrow = 3, byrow = FALSE)
  resolved_cols <- list(.spec("grp", is_group_col = TRUE), .spec("val"))

  pages <- writetfl:::paginate_rows(
    data, cell_h_mat, resolved_cols,
    group_vars = "grp",
    cont_row_h = 0, header_row_h = 0,
    content_height_in = 99,
    row_cont_msg = c("(continued above)", "(continued below)"),
    group_rule = FALSE,
    suppress_repeated_groups = FALSE
  )
  expect_equal(pages[[1L]]$row_heights_in, c(3, 3, 3))
})

# ---- end-to-end via export_tfl() -------------------------------------------

test_that("end-to-end: user's two-page rowspan example renders without error", {
  df <- dplyr::group_by(
    data.frame(A = rep("B\nC", 3L),
               D = c("E", "F", "G"),
               stringsAsFactors = FALSE),
    A
  )
  tbl <- tfl_table(df)
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

test_that("end-to-end: row_rule with a multi-row span renders without error", {
  df <- dplyr::group_by(
    data.frame(A = c("X\nY", "X\nY", "X\nY"),
               B = c("p", "q", "r"),
               stringsAsFactors = FALSE),
    A
  )
  tbl <- tfl_table(df, row_rule = TRUE)
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
})
