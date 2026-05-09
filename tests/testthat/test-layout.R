test_that("content height equals vp_height when no other sections present", {
  present <- c(header = FALSE, caption = FALSE, content = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_content_height(
    vp_height_in    = 7,
    section_heights = heights,
    present         = present,
    padding_in      = 0.1
  )
  expect_equal(result, 7)
})

test_that("content height subtracts header and one padding gap", {
  present <- c(header = TRUE, caption = FALSE, content = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.5, caption = 0, footnote = 0, footer = 0)
  result  <- compute_content_height(
    vp_height_in    = 7,
    section_heights = heights,
    present         = present,
    padding_in      = 0.1
  )
  expect_equal(result, 7 - 0.5 - 0.1)
})

test_that("content height subtracts header + caption + 2 padding gaps", {
  present <- c(header = TRUE, caption = TRUE, content = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.3, caption = 0.4, footnote = 0, footer = 0)
  result  <- compute_content_height(
    vp_height_in    = 7,
    section_heights = heights,
    present         = present,
    padding_in      = 0.1
  )
  expect_equal(result, 7 - 0.3 - 0.4 - 0.2)
})

test_that("content height subtracts all sections and 4 padding gaps", {
  present <- c(header = TRUE, caption = TRUE, content = TRUE,
               footnote = TRUE, footer = TRUE)
  heights <- list(header = 0.3, caption = 0.2, footnote = 0.15, footer = 0.25)
  result  <- compute_content_height(
    vp_height_in    = 7,
    section_heights = heights,
    present         = present,
    padding_in      = 0.1
  )
  expect_equal(result, 7 - 0.3 - 0.2 - 0.15 - 0.25 - 4 * 0.1)
})

test_that("padding count is 0 when only content is present", {
  present <- c(header = FALSE, caption = FALSE, content = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_content_height(7, heights, present, padding_in = 0.5)
  expect_equal(result, 7)
})

test_that("padding count is 1 when header and content present", {
  present <- c(header = TRUE, caption = FALSE, content = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.5, caption = 0, footnote = 0, footer = 0)
  result  <- compute_content_height(7, heights, present, padding_in = 0.5)
  expect_equal(result, 7 - 0.5 - 0.5)
})

test_that("padding count is 4 when all 5 sections present", {
  present <- c(header = TRUE, caption = TRUE, content = TRUE,
               footnote = TRUE, footer = TRUE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_content_height(7, heights, present, padding_in = 0.1)
  # 4 adjacent pairs: header-caption, caption-content, content-footnote, footnote-footer
  expect_equal(result, 7 - 4 * 0.1)
})

test_that("check_content_height adds error when content_h < min_content_height", {
  errors <- check_content_height(
    content_h_in       = 1.0,
    min_content_height = grid::unit(3, "inches"),
    errors             = character(0)
  )
  expect_length(errors, 1)
  expect_match(errors[[1]], "Content height")
})

test_that("check_content_height does not add error when content_h >= min_content_height", {
  errors <- check_content_height(
    content_h_in       = 4.0,
    min_content_height = grid::unit(3, "inches"),
    errors             = character(0)
  )
  expect_length(errors, 0)
})

test_that("check_content_height error message includes actual and minimum heights", {
  errors <- check_content_height(
    content_h_in       = 1.5,
    min_content_height = grid::unit(3, "inches"),
    errors             = character(0)
  )
  expect_match(errors[[1]], "1.5")
  expect_match(errors[[1]], "3")
})

test_that("check_content_height appends to existing error vector", {
  prior  <- "prior error"
  errors <- check_content_height(
    content_h_in       = 0.5,
    min_content_height = grid::unit(3, "inches"),
    errors             = prior
  )
  expect_length(errors, 2)
  expect_equal(errors[[1]], "prior error")
})

# ---------------------------------------------------------------------------
# check_content_width — issue #30
# ---------------------------------------------------------------------------

test_that("check_content_width is a no-op when content fits", {
  errors <- check_content_width(
    content_w_in    = 5,
    vp_width_in     = 7,
    overflow_action = "error",
    errors          = character(0)
  )
  expect_length(errors, 0)
})

test_that("check_content_width appends to errors under \"error\" action", {
  errors <- check_content_width(
    content_w_in    = 9,
    vp_width_in     = 7,
    overflow_action = "error",
    errors          = character(0),
    what            = "Content"
  )
  expect_length(errors, 1)
  expect_match(errors[[1]], "exceeds available content width")
  expect_match(errors[[1]], "9")
  expect_match(errors[[1]], "7")
})

test_that("check_content_width emits rlang::warn under \"warn\" action and leaves errors unchanged", {
  expect_warning(
    out <- check_content_width(
      content_w_in    = 9,
      vp_width_in     = 7,
      overflow_action = "warn",
      errors          = character(0)
    ),
    "exceeds available content width"
  )
  expect_length(out, 0)
})

test_that("check_content_width error message includes the diagnostic-mode hint", {
  errors <- check_content_width(
    content_w_in    = 9,
    vp_width_in     = 7,
    overflow_action = "error",
    errors          = character(0)
  )
  expect_match(errors[[1]], "overflow_action = \"warn\"", fixed = TRUE)
})

test_that("check_content_width warning text includes the diagnostic-mode hint", {
  expect_warning(
    check_content_width(
      content_w_in    = 9,
      vp_width_in     = 7,
      overflow_action = "warn",
      errors          = character(0)
    ),
    "overflow_action = \"warn\"",
    fixed = TRUE
  )
})

test_that("check_content_width respects custom `what` label", {
  errors <- check_content_width(
    content_w_in    = 9,
    vp_width_in     = 7,
    overflow_action = "error",
    errors          = character(0),
    what            = "Column 'foo'"
  )
  expect_match(errors[[1]], "Column 'foo' width", fixed = TRUE)
})

test_that("check_content_width tolerates near-equal widths within 1e-6", {
  errors <- check_content_width(
    content_w_in    = 7 + 1e-7,
    vp_width_in     = 7,
    overflow_action = "error",
    errors          = character(0)
  )
  expect_length(errors, 0)
})
