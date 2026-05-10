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
