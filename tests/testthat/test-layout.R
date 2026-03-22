test_that("figure height equals vp_height when no other sections present", {
  present <- c(header = FALSE, caption = FALSE, figure = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_figure_height(
    vp_height_in   = 7,
    section_heights = heights,
    present        = present,
    padding_in     = 0.1
  )
  expect_equal(result, 7)
})

test_that("figure height subtracts header and one padding gap", {
  present <- c(header = TRUE, caption = FALSE, figure = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.5, caption = 0, footnote = 0, footer = 0)
  result  <- compute_figure_height(
    vp_height_in   = 7,
    section_heights = heights,
    present        = present,
    padding_in     = 0.1
  )
  expect_equal(result, 7 - 0.5 - 0.1)
})

test_that("figure height subtracts header + caption + 2 padding gaps", {
  present <- c(header = TRUE, caption = TRUE, figure = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.3, caption = 0.4, footnote = 0, footer = 0)
  result  <- compute_figure_height(
    vp_height_in   = 7,
    section_heights = heights,
    present        = present,
    padding_in     = 0.1
  )
  expect_equal(result, 7 - 0.3 - 0.4 - 0.2)
})

test_that("figure height subtracts all sections and 4 padding gaps", {
  present <- c(header = TRUE, caption = TRUE, figure = TRUE,
               footnote = TRUE, footer = TRUE)
  heights <- list(header = 0.3, caption = 0.2, footnote = 0.15, footer = 0.25)
  result  <- compute_figure_height(
    vp_height_in   = 7,
    section_heights = heights,
    present        = present,
    padding_in     = 0.1
  )
  expect_equal(result, 7 - 0.3 - 0.2 - 0.15 - 0.25 - 4 * 0.1)
})

test_that("padding count is 0 when only figure is present", {
  present <- c(header = FALSE, caption = FALSE, figure = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_figure_height(7, heights, present, padding_in = 0.5)
  expect_equal(result, 7)
})

test_that("padding count is 1 when header and figure present", {
  present <- c(header = TRUE, caption = FALSE, figure = TRUE,
               footnote = FALSE, footer = FALSE)
  heights <- list(header = 0.5, caption = 0, footnote = 0, footer = 0)
  result  <- compute_figure_height(7, heights, present, padding_in = 0.5)
  expect_equal(result, 7 - 0.5 - 0.5)
})

test_that("padding count is 4 when all 5 sections present", {
  present <- c(header = TRUE, caption = TRUE, figure = TRUE,
               footnote = TRUE, footer = TRUE)
  heights <- list(header = 0, caption = 0, footnote = 0, footer = 0)
  result  <- compute_figure_height(7, heights, present, padding_in = 0.1)
  # 4 adjacent pairs: header-caption, caption-figure, figure-footnote, footnote-footer
  expect_equal(result, 7 - 4 * 0.1)
})

test_that("check_figure_height adds error when fig_h < min_figheight", {
  errors <- check_figure_height(
    fig_h_in      = 1.0,
    min_figheight = grid::unit(3, "inches"),
    errors        = character(0)
  )
  expect_length(errors, 1)
  expect_match(errors[[1]], "Figure height")
})

test_that("check_figure_height does not add error when fig_h >= min_figheight", {
  errors <- check_figure_height(
    fig_h_in      = 4.0,
    min_figheight = grid::unit(3, "inches"),
    errors        = character(0)
  )
  expect_length(errors, 0)
})

test_that("check_figure_height error message includes actual and minimum heights", {
  errors <- check_figure_height(
    fig_h_in      = 1.5,
    min_figheight = grid::unit(3, "inches"),
    errors        = character(0)
  )
  expect_match(errors[[1]], "1.5")
  expect_match(errors[[1]], "3")
})

test_that("check_figure_height appends to existing error vector", {
  prior  <- "prior error"
  errors <- check_figure_height(
    fig_h_in      = 0.5,
    min_figheight = grid::unit(3, "inches"),
    errors        = prior
  )
  expect_length(errors, 2)
  expect_equal(errors[[1]], "prior error")
})
