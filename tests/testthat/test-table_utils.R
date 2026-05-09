# test-table_utils.R — Tests for R/table_utils.R internal helpers

# Helper: open a scratch PDF and push a viewport for font-metric functions.
# Cleanup order matters: popViewport must run before dev.off().
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

# .width_in() / .height_in() ---------------------------------------------------

test_that(".width_in returns numeric inches matching convertWidth", {
  with_vp({
    u <- grid::unit(2, "inches")
    expect_equal(writetfl:::.width_in(u), 2)
    u_cm <- grid::unit(2.54, "cm")
    expect_equal(writetfl:::.width_in(u_cm), 1, tolerance = 0.01)
  })
})

test_that(".height_in returns numeric inches matching convertHeight", {
  with_vp({
    u <- grid::unit(3, "inches")
    expect_equal(writetfl:::.height_in(u), 3)
    u_cm <- grid::unit(2.54, "cm")
    expect_equal(writetfl:::.height_in(u_cm), 1, tolerance = 0.01)
  })
})

# .compute_group_sizes() ------------------------------------------------------

test_that(".compute_group_sizes returns integer(0) for a zero-row data frame", {
  result <- writetfl:::.compute_group_sizes(
    data.frame(grp = character(0L), stringsAsFactors = FALSE), "grp"
  )
  expect_equal(result, integer(0L))
})

test_that(".compute_group_sizes returns integer(0) when group_vars is empty", {
  result <- writetfl:::.compute_group_sizes(data.frame(a = 1:3), character(0L))
  expect_equal(result, integer(0L))
})

# .compute_group_rule_sizes() -------------------------------------------------

test_that(".compute_group_rule_sizes returns NA for the first group_start", {
  df <- data.frame(g = c("A", "A", "B"), stringsAsFactors = FALSE)
  res <- writetfl:::.compute_group_rule_sizes(df, "g")
  expect_equal(unname(res[[1L]]), NA_integer_)
})

test_that(".compute_group_rule_sizes uses outer-level size when outer changes", {
  # Two-level group: Cohort, Visit.  Cohort 1 has 2 visits (each 2 rows);
  # Cohort 2 has 2 visits (each 1 row).  At the boundary between the last
  # Cohort 1 row and the first Cohort 2 row, the inner (Cohort=2, Baseline)
  # group has 1 row but the outer Cohort=2 group has 2 rows.  The rule
  # size at that transition should be 2 (outer), not 1 (inner).
  df <- data.frame(
    Cohort = c(1, 1, 1, 1, 2, 2),
    Visit  = c("A", "A", "B", "B", "A", "B"),
    stringsAsFactors = FALSE
  )
  res <- writetfl:::.compute_group_rule_sizes(df, c("Cohort", "Visit"))
  # group_starts are rows c(1, 3, 5, 6).
  expect_equal(names(res), c("1", "3", "5", "6"))
  expect_equal(unname(res),
               c(NA_integer_,   # row 1: no transition before
                 2L,            # row 3: Visit changed within Cohort 1 → (Cohort=1, Visit=B) has 2 rows
                 2L,            # row 5: Cohort changed → (Cohort=2) outer group has 2 rows
                 1L))           # row 6: Visit changed within Cohort 2 → (Cohort=2, Visit=B) has 1 row
})

test_that(".compute_group_rule_sizes single-level: matches innermost size", {
  df <- data.frame(g = c("A", "A", "B", "C", "C", "C"), stringsAsFactors = FALSE)
  res <- writetfl:::.compute_group_rule_sizes(df, "g")
  expect_equal(names(res), c("1", "3", "4"))
  expect_equal(unname(res), c(NA_integer_, 1L, 3L))
})

test_that(".compute_group_rule_sizes returns integer(0) for empty inputs", {
  expect_equal(writetfl:::.compute_group_rule_sizes(
    data.frame(g = character(0L), stringsAsFactors = FALSE), "g"
  ), integer(0L))
  expect_equal(writetfl:::.compute_group_rule_sizes(
    data.frame(a = 1:3), character(0L)
  ), integer(0L))
})

# .collect_col_strings() ------------------------------------------------------

test_that(".collect_col_strings truncates to max_rows unique strings", {
  col    <- paste0("str", seq_len(20))   # 20 distinct strings
  result <- writetfl:::.collect_col_strings(col, "Label", "", max_rows = 3)
  # 1 label line + 3 data strings = 4 total
  expect_equal(length(result), 4L)
})

# .measure_max_string_width() -------------------------------------------------

test_that(".measure_max_string_width returns 0 for an empty character vector", {
  with_vp({
    w <- writetfl:::.measure_max_string_width(character(0L), grid::gpar())
    expect_equal(w, 0)
  })
})

# .wrap_text() ----------------------------------------------------------------

test_that(".wrap_text returns an empty string unchanged", {
  with_vp({
    result <- writetfl:::.wrap_text("", available_w_in = 2, gp = grid::gpar())
    expect_equal(result, "")
  })
})

test_that(".wrap_text returns a single word unchanged regardless of available width", {
  with_vp({
    result <- writetfl:::.wrap_text("Hello", available_w_in = 0.01, gp = grid::gpar())
    expect_equal(result, "Hello")
  })
})

test_that(".wrap_text inserts newlines when multi-word text overflows available width", {
  with_vp({
    long_text <- paste(rep("word", 20), collapse = " ")
    result    <- writetfl:::.wrap_text(long_text, available_w_in = 0.4,
                                       gp = grid::gpar(fontsize = 10))
    expect_true(grepl("\n", result, fixed = TRUE))
  })
})

test_that(".wrap_text preserves explicit paragraph breaks", {
  with_vp({
    text   <- "First paragraph.\nSecond paragraph."
    result <- writetfl:::.wrap_text(text, available_w_in = 5, gp = grid::gpar())
    expect_true(grepl("\n", result, fixed = TRUE))
  })
})

test_that(".wrap_text handles an empty paragraph (blank line between two lines)", {
  with_vp({
    # Middle paragraph is empty string — exercises the !nzchar(para) early return
    text   <- "Line one.\n\nLine three."
    result <- writetfl:::.wrap_text(text, available_w_in = 5, gp = grid::gpar())
    expect_true(nzchar(result))
  })
})

test_that(".wrap_text handles a whitespace-only paragraph (all words stripped)", {
  with_vp({
    # A paragraph consisting of spaces: after splitting on ' ' and nzchar-filtering,
    # words becomes character(0) — exercises the length(words) == 0L early return.
    text   <- "Before.\n   \nAfter."
    result <- writetfl:::.wrap_text(text, available_w_in = 5, gp = grid::gpar())
    expect_true(nzchar(result))
  })
})

test_that(".wrap_text returns a long unbreakable token unchanged", {
  with_vp({
    # A single token of 200 characters with no spaces — wider than any
    # reasonable available_w_in — must be returned unchanged because there
    # is no valid break point.
    token  <- paste(rep("X", 200), collapse = "")
    result <- writetfl:::.wrap_text(token, available_w_in = 0.01,
                                     gp = grid::gpar(fontsize = 10))
    expect_equal(result, token)
  })
})

test_that(".wrap_text wraps after an unbreakable first word", {
  with_vp({
    # First word exceeds available width, but subsequent words fit on
    # their own lines.
    long_word <- paste(rep("W", 100), collapse = "")
    text      <- paste(long_word, "a", "b")
    result    <- writetfl:::.wrap_text(text, available_w_in = 0.5,
                                       gp = grid::gpar(fontsize = 10))
    lines <- strsplit(result, "\n", fixed = TRUE)[[1L]]
    expect_equal(lines[[1L]], long_word)
    expect_gte(length(lines), 2L)
  })
})
