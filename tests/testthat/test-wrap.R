# test-wrap.R - Tests for R/wrap.R (the text-wrap module)

# Reuse the with_vp helper pattern from test-table_utils.R for measurement.
with_vp <- function(expr) {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  vp <- grid::viewport(width  = grid::unit(10, "inches"),
                       height = grid::unit(7.5, "inches"))
  grid::pushViewport(vp)
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
    unlink(f)
  })
  force(expr)
}

# wrap_breaks() constructor ----------------------------------------------------

test_that("wrap_breaks() returns a wrap_breaks object with whitespace defaults", {
  b <- writetfl:::wrap_breaks()
  expect_s3_class(b, "wrap_breaks")
  expect_setequal(b$drop, c(" ", "\t"))
  expect_equal(b$keep_before, character(0L))
})

test_that("wrap_breaks_default() returns the same as wrap_breaks()", {
  expect_equal(writetfl:::wrap_breaks_default(), writetfl:::wrap_breaks())
})

test_that(".is_wrap_breaks recognises wrap_breaks objects", {
  expect_true(writetfl:::.is_wrap_breaks(writetfl:::wrap_breaks()))
  expect_false(writetfl:::.is_wrap_breaks(list(drop = " ")))
  expect_false(writetfl:::.is_wrap_breaks(NULL))
})

test_that("wrap_breaks rejects non-character drop / keep_before", {
  expect_error(writetfl:::wrap_breaks(drop = 1L), regexp = "drop")
  expect_error(writetfl:::wrap_breaks(keep_before = 1L), regexp = "keep_before")
})

test_that("wrap_breaks rejects NA values", {
  expect_error(writetfl:::wrap_breaks(drop = c(" ", NA)), regexp = "NA")
  expect_error(writetfl:::wrap_breaks(keep_before = NA_character_), regexp = "NA")
})

test_that("wrap_breaks rejects multi-character entries", {
  expect_error(writetfl:::wrap_breaks(drop = c(" ", "ab")),
               regexp = "single character")
  expect_error(writetfl:::wrap_breaks(keep_before = "--"),
               regexp = "single character")
})

test_that("wrap_breaks rejects overlap between drop and keep_before", {
  expect_error(writetfl:::wrap_breaks(drop = c(" ", "-"), keep_before = "-"),
               regexp = "disjoint")
})

# .tokenize_for_wrap() --------------------------------------------------------

test_that(".tokenize_for_wrap splits on space (drop) - space is the lead of the next token", {
  toks <- writetfl:::.tokenize_for_wrap("a bb ccc",
                                        writetfl:::wrap_breaks_default())
  expect_equal(length(toks), 3L)
  expect_equal(vapply(toks, `[[`, "", "text"), c("a", "bb", "ccc"))
  expect_equal(vapply(toks, `[[`, "", "lead"), c("", " ", " "))
})

test_that(".tokenize_for_wrap keeps the keep_before character on the preceding token", {
  b    <- writetfl:::wrap_breaks(keep_before = "-")
  toks <- writetfl:::.tokenize_for_wrap("alpha-beta-gamma", b)
  expect_equal(vapply(toks, `[[`, "", "text"),
               c("alpha-", "beta-", "gamma"))
  expect_equal(vapply(toks, `[[`, "", "lead"), c("", "", ""))
})

test_that(".tokenize_for_wrap handles mixed drop and keep_before", {
  b    <- writetfl:::wrap_breaks(drop = " ", keep_before = "-")
  toks <- writetfl:::.tokenize_for_wrap("aa bb-cc dd", b)
  expect_equal(vapply(toks, `[[`, "", "text"),
               c("aa", "bb-", "cc", "dd"))
  expect_equal(vapply(toks, `[[`, "", "lead"),
               c("", " ", "", " "))
})

test_that(".tokenize_for_wrap returns an empty list for an empty string", {
  expect_equal(writetfl:::.tokenize_for_wrap("",
                                             writetfl:::wrap_breaks_default()),
               list())
})

# .wrap_string() core behavior -----------------------------------------------

test_that(".wrap_string returns NULL / empty input unchanged", {
  with_vp({
    expect_null(writetfl:::.wrap_string(NULL, 1, grid::gpar()))
    expect_equal(writetfl:::.wrap_string("", 1, grid::gpar()), "")
  })
})

test_that(".wrap_string preserves explicit \\n as paragraph breaks", {
  with_vp({
    out <- writetfl:::.wrap_string("first\nsecond", 5, grid::gpar())
    expect_equal(out, "first\nsecond")
  })
})

test_that(".wrap_string greedily breaks long text on whitespace", {
  with_vp({
    text <- paste(rep("word", 20), collapse = " ")
    out  <- writetfl:::.wrap_string(text, 0.4, grid::gpar(fontsize = 10))
    expect_true(grepl("\n", out, fixed = TRUE))
    # No line should still contain a space if breaking was needed
    lines <- strsplit(out, "\n", fixed = TRUE)[[1L]]
    expect_true(length(lines) > 1L)
  })
})

test_that(".wrap_string returns a single unbreakable token unchanged", {
  with_vp({
    token <- paste(rep("X", 200), collapse = "")
    out   <- writetfl:::.wrap_string(token, 0.01, grid::gpar(fontsize = 10))
    expect_equal(out, token)
  })
})

test_that(".wrap_string with keep_before breaks AFTER the keep char", {
  with_vp({
    b   <- writetfl:::wrap_breaks(keep_before = "-")
    # A wide enough font + tight width forces a break.
    out <- writetfl:::.wrap_string("alpha-beta-gamma", 0.5,
                                   grid::gpar(fontsize = 14), b)
    lines <- strsplit(out, "\n", fixed = TRUE)[[1L]]
    expect_gte(length(lines), 2L)
    # Each line that is not the last must end with "-"
    for (ln in lines[-length(lines)]) {
      expect_match(ln, "-$")
    }
  })
})

test_that(".wrap_string with NULL breaks falls back to defaults", {
  with_vp({
    out_null <- writetfl:::.wrap_string("aa bb cc", 0.3,
                                        grid::gpar(fontsize = 12),
                                        breaks = NULL)
    out_def  <- writetfl:::.wrap_string("aa bb cc", 0.3,
                                        grid::gpar(fontsize = 12))
    expect_equal(out_null, out_def)
  })
})

# .column_has_breakable_text() ------------------------------------------------

test_that(".column_has_breakable_text detects whitespace by default", {
  b <- writetfl:::wrap_breaks_default()
  expect_true(writetfl:::.column_has_breakable_text(c("hello world"), b))
  expect_false(writetfl:::.column_has_breakable_text(c("noBreak", "1.23"), b))
  expect_false(writetfl:::.column_has_breakable_text(character(0L), b))
})

test_that(".column_has_breakable_text detects keep_before chars", {
  b <- writetfl:::wrap_breaks(drop = character(0L), keep_before = "-")
  expect_true(writetfl:::.column_has_breakable_text(c("a-b"), b))
  expect_false(writetfl:::.column_has_breakable_text(c("ab", "cd"), b))
})

# .column_min_token_width_in() -----------------------------------------------

test_that(".column_min_token_width_in returns 0 for an empty input", {
  with_vp({
    w <- writetfl:::.column_min_token_width_in(character(0L), grid::gpar(),
                                               writetfl:::wrap_breaks_default())
    expect_equal(w, 0)
  })
})

test_that(".column_min_token_width_in returns the widest unbreakable token", {
  with_vp({
    gp <- grid::gpar(fontsize = 12)
    b  <- writetfl:::wrap_breaks_default()
    short <- writetfl:::.column_min_token_width_in("aa bb", gp, b)
    long  <- writetfl:::.column_min_token_width_in("aa LongUnbreakableToken", gp, b)
    expect_gt(long, short)
  })
})

test_that(".column_min_token_width_in counts keep_before char as part of the left token", {
  with_vp({
    gp <- grid::gpar(fontsize = 12)
    b  <- writetfl:::wrap_breaks(keep_before = "-")
    # "alpha-beta" tokenises to "alpha-" and "beta"; the longest is "alpha-"
    w_with_dash <- writetfl:::.column_min_token_width_in("alpha-beta", gp, b)
    w_no_dash   <- writetfl:::.column_min_token_width_in("alphabeta", gp,
                                                         writetfl:::wrap_breaks_default())
    expect_lt(w_with_dash, w_no_dash)   # break after "-" reduces the floor
  })
})

# .wrap_label_for_width() ----------------------------------------------------

test_that(".wrap_label_for_width returns NULL / empty input unchanged", {
  expect_null(writetfl:::.wrap_label_for_width(NULL, 1, 0.1, grid::gpar(),
                                               writetfl:::wrap_breaks_default()))
  expect_equal(
    writetfl:::.wrap_label_for_width("", 1, 0.1, grid::gpar(),
                                     writetfl:::wrap_breaks_default()),
    ""
  )
})

test_that(".wrap_label_for_width subtracts horizontal padding from the available width", {
  with_vp({
    gp <- grid::gpar(fontsize = 12)
    b  <- writetfl:::wrap_breaks_default()
    out <- writetfl:::.wrap_label_for_width("Concomitant Medication Class",
                                            width_in = 1.0,
                                            h_pad_in = 0.2,
                                            gp = gp, breaks = b)
    expect_true(grepl("\n", out, fixed = TRUE))
  })
})

# .compute_wrapped_widths() water-fill ---------------------------------------

test_that(".compute_wrapped_widths is a no-op when no column is wrap-eligible", {
  resolved <- list(
    list(col = "a", label = "a", wrap = FALSE, is_group_col = FALSE),
    list(col = "b", label = "b", wrap = FALSE, is_group_col = FALSE)
  )
  data <- data.frame(a = "aa bb", b = "cc dd", stringsAsFactors = FALSE)
  tbl  <- list(gp = list(), wrap_breaks = writetfl:::wrap_breaks_default(),
               line_height = 1.05, na_string = "", max_measure_rows = Inf,
               cell_padding = grid::unit(c(0, 0, 0, 0), "inches"))
  out <- writetfl:::.compute_wrapped_widths(
    widths_in = c(2, 2),
    resolved_cols = resolved,
    data = data, tbl = tbl,
    content_width_in = 3,    # would force narrowing if anything were eligible
    h_pad_in = 0, min_in = 0.5,
    pg_width = 11, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  expect_equal(out, c(2, 2))
})

test_that(".compute_wrapped_widths narrows the widest wrap-eligible col first", {
  resolved <- list(
    list(col = "a", label = "a", wrap = TRUE, is_group_col = FALSE),
    list(col = "b", label = "b", wrap = TRUE, is_group_col = FALSE)
  )
  # both columns have only " " breaks; lots of small words -> floor is small
  data <- data.frame(a = paste(rep("xx", 30), collapse = " "),
                     b = paste(rep("yy", 30), collapse = " "),
                     stringsAsFactors = FALSE)
  tbl  <- list(gp = list(), wrap_breaks = writetfl:::wrap_breaks_default(),
               line_height = 1.05, na_string = "", max_measure_rows = Inf,
               cell_padding = grid::unit(c(0, 0, 0, 0), "inches"))
  out <- writetfl:::.compute_wrapped_widths(
    widths_in = c(4, 2),     # widest = a
    resolved_cols = resolved,
    data = data, tbl = tbl,
    content_width_in = 3,
    h_pad_in = 0, min_in = 0.2,
    pg_width = 11, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  # Total fits within the target.
  expect_lte(sum(out), 3 + 1e-6)
  # The widest column shrank.
  expect_lt(out[[1]], 4)
})

test_that(".compute_wrapped_widths respects the longest-token floor", {
  resolved <- list(
    list(col = "a", label = "a", wrap = TRUE, is_group_col = FALSE)
  )
  # A single unbreakable token whose rendered width sets the floor.
  long <- paste(rep("X", 60), collapse = "")
  data <- data.frame(a = long, stringsAsFactors = FALSE)
  tbl  <- list(gp = list(), wrap_breaks = writetfl:::wrap_breaks_default(),
               line_height = 1.05, na_string = "", max_measure_rows = Inf,
               cell_padding = grid::unit(c(0, 0, 0, 0), "inches"))
  out <- writetfl:::.compute_wrapped_widths(
    widths_in = c(8),
    resolved_cols = resolved,
    data = data, tbl = tbl,
    content_width_in = 0.5,   # tiny target - much less than the token width
    h_pad_in = 0, min_in = 0.1,
    pg_width = 11, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  # The result is bounded below by the widest token's rendered width.
  with_vp({
    floor_w <- writetfl:::.column_min_token_width_in(
      long, grid::gpar(), writetfl:::wrap_breaks_default()
    )
  })
  expect_gte(out[[1]], floor_w - 1e-6)
})

# .water_fill_to_budget() ----------------------------------------------------

test_that(".water_fill_to_budget no-op when sum already <= budget", {
  out <- writetfl:::.water_fill_to_budget(
    widths_in     = c(1, 2, 1),
    widths_min    = c(0.5, 0.5, 0.5),
    wrap_eligible = c(TRUE, TRUE, FALSE),
    budget_in     = 10
  )
  expect_equal(out, c(1, 2, 1))
})

test_that(".water_fill_to_budget snaps widths_in up to widths_min on entry", {
  out <- writetfl:::.water_fill_to_budget(
    widths_in     = c(0.1, 0.1),
    widths_min    = c(0.5, 0.5),
    wrap_eligible = c(TRUE, TRUE),
    budget_in     = 5
  )
  expect_equal(out, c(0.5, 0.5))
})

test_that(".water_fill_to_budget shrinks widest wrap-eligible together", {
  out <- writetfl:::.water_fill_to_budget(
    widths_in     = c(4, 4, 1),
    widths_min    = c(0.5, 0.5, 1),
    wrap_eligible = c(TRUE, TRUE, FALSE),
    budget_in     = 5
  )
  # The two equally-wide wrap cols share the deficit; the unbreakable col
  # is preserved at its width.
  expect_equal(out[[3]], 1)
  expect_equal(out[[1]], out[[2]], tolerance = 1e-6)
  expect_equal(sum(out), 5, tolerance = 1e-6)
})

test_that(".water_fill_to_budget honors floors even when budget is too tight", {
  out <- writetfl:::.water_fill_to_budget(
    widths_in     = c(5, 5),
    widths_min    = c(1, 1),
    wrap_eligible = c(TRUE, TRUE),
    budget_in     = 1   # impossible: both at floor sum to 2
  )
  # Hits floor; sum may still exceed budget.
  expect_equal(out, c(1, 1))
  expect_gt(sum(out), 1)
})

test_that(".water_fill_to_budget leaves non-wrap cols alone", {
  out <- writetfl:::.water_fill_to_budget(
    widths_in     = c(3, 3),
    widths_min    = c(1, 1),
    wrap_eligible = c(FALSE, FALSE),
    budget_in     = 1
  )
  expect_equal(out, c(3, 3))   # nothing shrinkable; budget breached
})

# .reconcile_page_widths() ---------------------------------------------------

test_that(".reconcile_page_widths assigns each non-group col its per-page width", {
  # 3 data cols (no group cols) split across 2 pages: page 1 = {1, 2},
  # page 2 = {3}.
  out <- writetfl:::.reconcile_page_widths(
    per_page_widths = list(c(1.5, 2.0), c(3.0)),
    col_groups      = list(c(1L, 2L),   c(3L)),
    n_group_cols    = 0L,
    n_cols          = 3L
  )
  expect_equal(out, c(1.5, 2.0, 3.0))
})

test_that(".reconcile_page_widths group cols take the MIN width across pages", {
  # 1 group col (col 1) + 2 data cols (2, 3) split across 2 pages.
  # Page 1: {1, 2} with widths (0.8, 1.5).
  # Page 2: {1, 3} with widths (0.6, 2.0).
  # Group col should resolve to min(0.8, 0.6) = 0.6.
  out <- writetfl:::.reconcile_page_widths(
    per_page_widths = list(c(0.8, 1.5), c(0.6, 2.0)),
    col_groups      = list(c(1L, 2L),   c(1L, 3L)),
    n_group_cols    = 1L,
    n_cols          = 3L
  )
  expect_equal(out, c(0.6, 1.5, 2.0))
})

# col_split_strategy = "balanced" vs "wrap_first" end-to-end -----------------

test_that("balanced strategy gives wider per-page columns than wrap_first when table page-splits", {
  # 2 wrap-eligible string cols (a, b) + 2 unbreakable single-token cols
  # (c, d).  Total natural > content_width, and the page-split puts
  # (a, b, c) on page 1 and (d) on page 2.  Under wrap_first the
  # whole-table water-fill crushes a and b to their floors so the table
  # fits *somewhere*; under balanced, page 1 water-fills locally so a and
  # b get nearly the full page-1 slack.
  df <- data.frame(
    a = rep(paste(rep("alpha", 8), collapse = " "), 5),
    b = rep(paste(rep("bravo", 8), collapse = " "), 5),
    c = rep("unbreak_one_token_here", 5),
    d = rep("another_long_token_unbreakable", 5),
    stringsAsFactors = FALSE
  )
  measure <- function(strat) {
    tbl <- tfl_table(df, col_split_strategy = strat)
    rcs <- writetfl:::resolve_col_specs(tbl)
    cwr <- writetfl:::compute_col_widths(
      rcs, tbl$data, content_width_in = 5, tbl, pg_width = 6, pg_height = 8.5,
      margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
    )
    vapply(cwr$resolved_cols, "[[", numeric(1L), "width_in")
  }
  w_first <- measure("wrap_first")
  w_balan <- measure("balanced")
  # Columns a and b end up much wider under balanced.
  expect_gt(w_balan[[1]], w_first[[1]])
  expect_gt(w_balan[[2]], w_first[[2]])
  # Column c and d are unchanged (single unbreakable tokens, same min/natural).
  expect_equal(w_balan[[3]], w_first[[3]], tolerance = 1e-3)
  expect_equal(w_balan[[4]], w_first[[4]], tolerance = 1e-3)
})

test_that("balanced strategy is identical to wrap_first when table fits one page", {
  # Small data that fits on a single page width: both strategies should
  # arrive at the same widths.
  df <- data.frame(
    a = c("Alpha", "Beta", "Gamma"),
    b = c(10L, 20L, 30L),
    stringsAsFactors = FALSE
  )
  measure <- function(strat) {
    tbl <- tfl_table(df, col_split_strategy = strat)
    rcs <- writetfl:::resolve_col_specs(tbl)
    cwr <- writetfl:::compute_col_widths(
      rcs, tbl$data, content_width_in = 5, tbl, pg_width = 6, pg_height = 8.5,
      margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
    )
    vapply(cwr$resolved_cols, "[[", numeric(1L), "width_in")
  }
  expect_equal(measure("balanced"), measure("wrap_first"), tolerance = 1e-6)
})

test_that("balanced strategy pins group columns at min width across pages", {
  # 1 group col + 2 data cols, table page-splits.  Group col width should
  # equal its min (longest-unbreakable-token + h_pad) across both pages.
  df <- data.frame(
    grp = rep(c("G1", "G2"), each = 3),
    a   = rep(paste(rep("alpha", 8), collapse = " "), 6),
    b   = rep("unbreak_long_token_here_extra", 6),
    stringsAsFactors = FALSE
  )
  df <- dplyr::group_by(df, grp)
  tbl <- tfl_table(df, col_split_strategy = "balanced")
  rcs <- writetfl:::resolve_col_specs(tbl)
  cwr <- writetfl:::compute_col_widths(
    rcs, tbl$data, content_width_in = 5, tbl, pg_width = 6, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  # Group col is column 1; its width_in should be the (smallest) per-page
  # value, which is its min width (== max(min_col_width, "G1"/"G2" + pad)).
  grp_w <- cwr$resolved_cols[[1]]$width_in
  grp_min <- cwr$resolved_cols[[1]]$width_min_in %||% grp_w
  expect_equal(grp_w, grp_min, tolerance = 1e-6)
})

# tfl_table arg validation ---------------------------------------------------

test_that("tfl_table validates col_split_strategy", {
  expect_error(tfl_table(data.frame(a = 1), col_split_strategy = "fancy"),
               regexp = "col_split_strategy")
  expect_no_error(tfl_table(data.frame(a = 1), col_split_strategy = "wrap_first"))
  expect_no_error(tfl_table(data.frame(a = 1), col_split_strategy = "balanced"))
})

test_that("tfl_table validates row_overflow_max_retries (non-negative integer)", {
  expect_error(tfl_table(data.frame(a = 1), row_overflow_max_retries = -1L),
               regexp = "row_overflow_max_retries")
  expect_error(tfl_table(data.frame(a = 1),
                          row_overflow_max_retries = c(1L, 2L)),
               regexp = "row_overflow_max_retries")
  expect_no_error(tfl_table(data.frame(a = 1), row_overflow_max_retries = 0L))
  expect_no_error(tfl_table(data.frame(a = 1), row_overflow_max_retries = 5L))
})

# paginate_rows() collect_overflows mode --------------------------------------

test_that("paginate_rows(collect_overflows = TRUE) returns pages + overflow info instead of aborting", {
  # 2-row data; force the first row's content to be very tall by feeding a
  # cell_h_mat where row 1's cell height exceeds the page content height.
  # The function should NOT abort under collect_overflows = TRUE.
  data <- data.frame(a = c("x", "y"), stringsAsFactors = FALSE)
  resolved_cols <- list(list(col = "a", label = "a", wrap = TRUE,
                              is_group_col = FALSE, width_in = 0.5))
  cell_h_mat <- matrix(c(20, 0.2), nrow = 2L, ncol = 1L)   # row 1 = 20 in
  res <- writetfl:::paginate_rows(
    data, cell_h_mat, resolved_cols, group_vars = character(0L),
    cont_row_h = 0.2, header_row_h = 0.3, content_height_in = 5,
    row_cont_msg = c("(continued)", "(continued)"), group_rule = FALSE,
    collect_overflows = TRUE
  )
  expect_named(res, c("pages", "overflows"))
  expect_gte(length(res$overflows), 1L)
  expect_equal(res$overflows[[1L]]$row, 1L)
  expect_equal(res$overflows[[1L]]$bottleneck_col, 1L)
})

test_that("row_overflow_max_retries = 0L disables the retry loop and errors immediately", {
  # Single 8000-character cell forced into a narrow column - no number of
  # retries will rescue it.
  long_essay <- paste(rep(paste(rep("aa bb cc dd ee ff", 3), collapse = " "),
                          150),
                      collapse = " ")
  df  <- data.frame(notes = long_essay, stringsAsFactors = FALSE)
  tbl <- tfl_table(
    df,
    cols = list(tfl_colspec("notes", width = grid::unit(0.8, "inches"),
                             wrap = TRUE)),
    row_overflow_max_retries = 0L
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_error(
    export_tfl(tbl, file = f, pg_width = 4, pg_height = 8.5,
               min_content_height = grid::unit(0.5, "inches")),
    regexp = "exceeds the available page content height"
  )
})

test_that("row_overflow_max_retries > 0 still ultimately errors when content is genuinely too long", {
  # Default retry cap (5L) - same impossible input.  Retries widen the
  # column but eventually exhaust without resolving; the final paginate_rows
  # call goes through overflow_action = "error".
  long_essay <- paste(rep(paste(rep("aa bb cc dd ee ff", 3), collapse = " "),
                          150),
                      collapse = " ")
  df  <- data.frame(notes = long_essay, stringsAsFactors = FALSE)
  tbl <- tfl_table(
    df,
    cols = list(tfl_colspec("notes", width = grid::unit(0.8, "inches"),
                             wrap = TRUE)),
    row_overflow_max_retries = 5L
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_error(
    export_tfl(tbl, file = f, pg_width = 4, pg_height = 8.5,
               min_content_height = grid::unit(0.5, "inches")),
    regexp = "exceeds the available page content height"
  )
})
