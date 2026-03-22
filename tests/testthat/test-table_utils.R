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

# .open_scratch_device() / .close_scratch_device() ----------------------------

test_that(".open_scratch_device opens a PDF device when for_preview = FALSE", {
  scratch_file <- writetfl:::.open_scratch_device(11, 8.5, for_preview = FALSE)
  on.exit(writetfl:::.close_scratch_device(scratch_file), add = TRUE)

  expect_null(scratch_file)
  expect_true(grepl("pdf", names(grDevices::dev.cur()), ignore.case = TRUE))
})

test_that(".open_scratch_device opens a PNG device when for_preview = TRUE", {
  scratch_file <- writetfl:::.open_scratch_device(11, 8.5,
                                                   for_preview = TRUE,
                                                   scratch_dpi = 72L)
  on.exit(writetfl:::.close_scratch_device(scratch_file), add = TRUE)

  expect_true(is.character(scratch_file) && nzchar(scratch_file))
  expect_true(grepl("png", names(grDevices::dev.cur()), ignore.case = TRUE))
})

test_that(".close_scratch_device removes the temp file for PNG devices", {
  scratch_file <- writetfl:::.open_scratch_device(11, 8.5,
                                                   for_preview = TRUE,
                                                   scratch_dpi = 72L)
  expect_true(file.exists(scratch_file))
  writetfl:::.close_scratch_device(scratch_file)
  expect_false(file.exists(scratch_file))
})

test_that(".open_scratch_device defaults to 72 DPI when scratch_dpi is NULL", {
  scratch_file <- writetfl:::.open_scratch_device(11, 8.5,
                                                   for_preview = TRUE,
                                                   scratch_dpi = NULL)
  on.exit(writetfl:::.close_scratch_device(scratch_file), add = TRUE)

  # Device should be open and functional
  expect_true(grDevices::dev.cur() > 1L)
})
