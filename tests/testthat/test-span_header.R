# test-span_header.R — Spanning (multi-row) column headers (D-53).
#
# Covers the pure span algorithm (.split_header_label, .compute_header_spans,
# .slice_header_spans), col_header_sep validation, and end-to-end width /
# pagination / drawing behavior.

# --- helpers (top-level per CLAUDE.md) --------------------------------------

# Compact [start,end,text] tuples for one header row.
sp_row <- function(spans, r) {
  lapply(spans$cells_by_row[[r]], function(c) list(c$start, c$end, c$text))
}

# Column x-left / x-right (inches, x_offset removed) for a page grob's columns.
col_x_bounds <- function(page_cols) {
  w <- vapply(page_cols, function(cs) cs$width_in, numeric(1L))
  list(left = c(0, cumsum(w)[-length(w)]), right = cumsum(w), w = w)
}

# Capture the horizontal rules drawn while rendering `tbl` (preview mode),
# returned as a list of list(y, x1, x2) in inches.  Used to check spanner
# underline placement.
capture_header_hlines <- function(tbl) {
  .GlobalEnv$.WTFL_HL <- list()
  suppressMessages(trace(
    grid:::grid.lines,
    tracer = quote({
      yy <- tryCatch(grid::convertY(y, "in", valueOnly = TRUE),
                     error = function(e) NA)
      xx <- tryCatch(grid::convertX(x, "in", valueOnly = TRUE),
                     error = function(e) c(NA, NA))
      if (length(yy) == 2 && abs(yy[[1]] - yy[[2]]) < 1e-6) {
        .GlobalEnv$.WTFL_HL[[length(.GlobalEnv$.WTFL_HL) + 1L]] <-
          list(y = round(yy[[1]], 4), x1 = xx[[1]], x2 = xx[[2]])
      }
    }),
    print = FALSE, where = asNamespace("grid")
  ))
  on.exit(suppressMessages(untrace(grid:::grid.lines,
                                   where = asNamespace("grid"))), add = TRUE)
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  export_tfl(tbl, preview = TRUE)
  .GlobalEnv$.WTFL_HL
}

# Run the pagination pipeline for one tfl_table and return the page grobs.
pagelist_grobs <- function(tbl, pg_width = 11, pg_height = 8.5) {
  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  on.exit(grDevices::dev.off(), add = TRUE)
  pages <- tfl_table_to_pagelist(tbl, pg_width, pg_height, dots = list(),
                                 page_num = NULL)
  lapply(pages, function(p) p$content)
}

# ---------------------------------------------------------------------------
# .split_header_label()
# ---------------------------------------------------------------------------

test_that(".split_header_label splits and preserves empty fields", {
  expect_equal(.split_header_label("A|||B|||C", "|||"), c("A", "B", "C"))
  expect_equal(.split_header_label("A", "|||"), "A")
  expect_equal(.split_header_label("Top||||||Bottom", "|||"), c("Top", "", "Bottom"))
  expect_equal(.split_header_label("A|||", "|||"), c("A", ""))       # trailing empty kept
  expect_equal(.split_header_label("|||b", "|||"), c("", "b"))       # leading empty
  expect_equal(.split_header_label("", "|||"), "")
})

# ---------------------------------------------------------------------------
# .compute_header_spans()
# ---------------------------------------------------------------------------

test_that("identical leaves under different parents do NOT merge", {
  sp <- .compute_header_spans(c("Placebo|||n", "Drug|||n"), "|||", 0L)
  expect_equal(sp$R, 2L)
  expect_equal(sp$spanned_gap, FALSE)                 # no atom
  expect_equal(sp_row(sp, 2L), list(list(1L, 1L, "n"), list(2L, 2L, "n")))
})

test_that("shared super-header below an empty top row DOES merge", {
  sp <- .compute_header_spans(c("|||Grp|||a", "|||Grp|||b"), "|||", 0L)
  expect_equal(sp$R, 3L)
  expect_true(sp$spanned_gap[[1L]])
  expect_equal(sp_row(sp, 2L), list(list(1L, 2L, "Grp")))
  expect_equal(sp$leaf_labels, c("a", "b"))
})

test_that("mixed shallow/deep labels keep shallow columns free", {
  sp <- .compute_header_spans(c("Age", "Trt|||Dose", "Trt|||Resp"), "|||", 0L)
  expect_equal(sp$R, 2L)
  expect_equal(sp$spanned_gap, c(FALSE, TRUE))        # Age free; Trt spans 2-3
  expect_equal(sp_row(sp, 1L), list(list(1L, 1L, ""), list(2L, 3L, "Trt")))
})

test_that("group/data divide is a hard boundary", {
  sp <- .compute_header_spans(c("grp", "Trt|||A", "Trt|||B"), "|||", 1L)
  expect_equal(sp$spanned_gap, c(FALSE, TRUE))        # divide never spanned
})

test_that("trailing-space escape hatch prevents a leaf merge", {
  sp <- .compute_header_spans(c("Trt|||n", "Trt|||n "), "|||", 0L)
  expect_equal(sp_row(sp, 1L), list(list(1L, 2L, "Trt")))   # parent still spans
  expect_equal(sp_row(sp, 2L), list(list(1L, 1L, "n"), list(2L, 2L, "n")))
  expect_equal(sp$leaf_labels, c("n", "n"))                 # trimmed for display
})

test_that("feature off / no separator returns the trivial R==1 structure", {
  off <- .compute_header_spans(c("Placebo|||n", "Drug|||n"), NA, 0L)
  expect_equal(off$R, 1L)
  expect_equal(off$leaf_labels, c("Placebo|||n", "Drug|||n"))  # verbatim
  expect_equal(off$spanned_gap, FALSE)

  none <- .compute_header_spans(c("mpg", "hp"), "|||", 0L)
  expect_equal(none$R, 1L)
  expect_equal(none$leaf_labels, c("mpg", "hp"))
})

# ---------------------------------------------------------------------------
# .slice_header_spans()
# ---------------------------------------------------------------------------

test_that(".slice_header_spans re-indexes on-page cells and drops off-page ones", {
  # grp | (Trt: A B) | (Ctl: C D)
  sp <- .compute_header_spans(
    c("grp", "Trt|||A", "Trt|||B", "Ctl|||C", "Ctl|||D"), "|||", 1L)
  # Page shows grp (1) + the Ctl atom (4,5).
  sl <- .slice_header_spans(sp, c(1L, 4L, 5L))
  expect_equal(sl$R, sp$R)
  # The Ctl super-header cell is present, re-indexed to local cols 2-3.
  expect_true(any(vapply(sl$cells_by_row[[1L]],
                         function(c) c$start == 2L && c$end == 3L && c$text == "Ctl",
                         logical(1L))))
  # The Trt cell (full cols 2-3) is entirely off this page and dropped.
  expect_false(any(vapply(sl$cells_by_row[[1L]],
                          function(c) identical(c$text, "Trt"), logical(1L))))
})

# ---------------------------------------------------------------------------
# col_header_sep validation
# ---------------------------------------------------------------------------

test_that("tfl_table validates col_header_sep", {
  df <- data.frame(a = 1, b = 2)
  expect_error(tfl_table(df, col_header_sep = c("a", "b")), "col_header_sep")
  expect_error(tfl_table(df, col_header_sep = ""), "col_header_sep")
  expect_error(tfl_table(df, col_header_sep = "a\nb"), "newline")
  expect_s3_class(tfl_table(df, col_header_sep = "|||"), "tfl_table")
  expect_s3_class(tfl_table(df, col_header_sep = NA), "tfl_table")   # disabled
})

# ---------------------------------------------------------------------------
# End-to-end: width, drawing geometry, pagination
# ---------------------------------------------------------------------------

test_that("a spanning-header table renders without error", {
  df <- data.frame(id = c("A", "B", "C"), n1 = 1:3, m1 = c(1.1, 2.2, 3.3),
                   n2 = 4:6, m2 = c(4.4, 5.5, 6.6))
  tbl <- tfl_table(df, col_labels = c(
    id = "Subject", n1 = "Placebo|||n", m1 = "Placebo|||Mean",
    n2 = "Drug A|||n", m2 = "Drug A|||Mean"))
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})

test_that("a spanner's x-extent is the sum of the columns beneath it (issue: width bug)", {
  df <- data.frame(id = c("A", "B", "C"), n1 = 1:3, m1 = c(1.1, 2.2, 3.3),
                   n2 = 4:6, m2 = c(4.4, 5.5, 6.6))
  tbl <- tfl_table(df, col_labels = c(
    id = "Subject", n1 = "Placebo|||n", m1 = "Placebo|||Mean",
    n2 = "Drug A|||n", m2 = "Drug A|||Mean"))
  grob <- pagelist_grobs(tbl)[[1L]]

  spans_page <- .slice_header_spans(grob$header_spans, grob$col_group_idx)
  b <- col_x_bounds(grob$page_cols)
  n_cols   <- length(grob$page_cols)
  total_w  <- sum(b$w)

  # The two super-header cells live in row 1.
  supers <- Filter(function(c) c$end > c$start, spans_page$cells_by_row[[1L]])
  expect_length(supers, 2L)
  for (cell in supers) {
    extent <- b$right[[cell$end]] - b$left[[cell$start]]
    # Width equals the summed member widths...
    expect_equal(extent, sum(b$w[cell$start:cell$end]), tolerance = 1e-9)
    # ...spans more than its first column (not clipped at the first column)...
    expect_gt(extent, b$w[[cell$start]])
    # ...and never extends past the last column.
    expect_lte(b$right[[cell$end]], total_w + 1e-9)
  }
})

test_that("a spanned block is never split across column pages (atomic)", {
  # Columns aaa(2) + bbb(3) are bound by the "Pair" spanner; a narrow page
  # forces a column split, but the pair must stay together.
  df <- data.frame(
    id = c("r1", "r2"), aaa = 1:2, bbb = 3:4, ccc = 5:6
  )
  tbl <- tfl_table(
    df,
    col_labels = c(id = "ID", aaa = "Pair|||Left", bbb = "Pair|||Right",
                   ccc = "Solo"),
    # Named LIST of units (a unit *vector* would not resolve by name).
    col_widths = stats::setNames(
      list(grid::unit(1, "in"), grid::unit(2.2, "in"),
           grid::unit(2.2, "in"), grid::unit(2.2, "in")),
      c("id", "aaa", "bbb", "ccc")),
    allow_col_split = TRUE
  )
  grobs <- pagelist_grobs(tbl, pg_width = 7, pg_height = 8.5)
  col_pages <- unique(lapply(grobs, function(g) g$col_group_idx))
  expect_gt(length(col_pages), 1L)                 # a split really happened
  for (idx in col_pages) {
    expect_equal(2L %in% idx, 3L %in% idx)          # aaa present iff bbb present
  }
})

test_that("a spanner wider than the page errors under overflow_action = 'error'", {
  df <- data.frame(a = 1, b = 2)
  tbl <- tfl_table(
    df,
    col_labels = c(a = "Enormous Spanning Header|||a", b = "Enormous Spanning Header|||b"),
    col_widths = stats::setNames(list(grid::unit(6, "in"), grid::unit(6, "in")),
                                 c("a", "b")),
    allow_col_split = FALSE
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  # 12 in of columns cannot fit a ~10 in content width; the atom cannot split.
  expect_error(export_tfl(tbl, file = f, pg_width = 11, pg_height = 8.5))
})

test_that("R==1 regression: NA separator matches default when no label spans", {
  df <- data.frame(id = c("A", "B"), x = 1:2, y = 3:4)
  labs <- c(id = "ID", x = "X", y = "Y")
  g_default <- pagelist_grobs(tfl_table(df, col_labels = labs))
  g_off     <- pagelist_grobs(tfl_table(df, col_labels = labs, col_header_sep = NA))
  w_default <- vapply(g_default[[1L]]$page_cols, function(cs) cs$width_in, 0)
  w_off     <- vapply(g_off[[1L]]$page_cols,     function(cs) cs$width_in, 0)
  expect_equal(w_default, w_off)
  expect_equal(length(g_default), length(g_off))
  expect_equal(g_default[[1L]]$header_spans$R, 1L)
})

test_that("spanner underlines are drawn with a side-margin gap between groups", {
  resp <- data.frame(subgroup = c("All", "A", "B"),
                     pn = c(118L, 71L, 47L), pm = c(26.3, 25.4, 27.7),
                     an = c(120L, 74L, 46L), am = c(56.7, 59.5, 52.2))
  labs <- c(subgroup = "Subgroup", pn = "Placebo|||n", pm = "Placebo|||Mean",
            an = "Active|||n", am = "Active|||Mean")

  on <- capture_header_hlines(tfl_table(resp, col_labels = labs))
  # Two arm underlines + the full-width col_header_rule.
  expect_equal(length(on), 3L)

  # The two arm underlines share the topmost y; their gap equals the
  # horizontal (side) cell padding (default 0.5 lines).
  ys      <- vapply(on, `[[`, numeric(1L), "y")
  top_y   <- max(ys)
  arms    <- on[abs(ys - top_y) < 1e-6]
  expect_equal(length(arms), 2L)
  arms    <- arms[order(vapply(arms, function(l) min(l$x1, l$x2), numeric(1L)))]
  gap     <- min(arms[[2L]]$x1, arms[[2L]]$x2) - max(arms[[1L]]$x1, arms[[1L]]$x2)
  side_pad <- grid::convertWidth(grid::unit(0.5, "lines"), "in", valueOnly = TRUE)
  expect_equal(gap, side_pad, tolerance = 1e-3)

  # Toggle off -> only the full-width col_header_rule remains.
  off <- capture_header_hlines(
    tfl_table(resp, col_labels = labs, col_header_span_rule = FALSE))
  expect_equal(length(off), 1L)
})

test_that("two identical adjacent leaves do NOT merge without a separator", {
  # No "|||" anywhere -> R==1 -> the two 'n' columns render independently.
  df  <- data.frame(g = c("x", "y"), n = 1:2, n2 = 3:4)
  tbl <- tfl_table(df, col_labels = c(g = "G", n = "n", n2 = "n"))
  grob <- pagelist_grobs(tbl)[[1L]]
  expect_equal(grob$header_spans$R, 1L)
  expect_equal(grob$header_spans$spanned_gap, rep(FALSE, 2L))
})
