test_that("validate_file_arg errors on non-character file", {
  expect_error(validate_file_arg(123),        regexp = "\\.pdf")
  expect_error(validate_file_arg(NULL),       regexp = "\\.pdf")
  expect_error(validate_file_arg(TRUE),       regexp = "\\.pdf")
})

test_that("validate_file_arg errors on length > 1 file", {
  expect_error(validate_file_arg(c("a.pdf", "b.pdf")), regexp = "\\.pdf")
})

test_that("validate_file_arg errors when file does not end in .pdf", {
  expect_error(validate_file_arg("report.docx"), regexp = "\\.pdf")
  expect_error(validate_file_arg("report.PDF"),  regexp = "\\.pdf")  # case sensitive
  expect_error(validate_file_arg("report"),      regexp = "\\.pdf")
})

test_that("validate_file_arg passes for valid .pdf path", {
  expect_no_error(validate_file_arg("report.pdf"))
  expect_no_error(validate_file_arg("./output/report.pdf"))
  expect_no_error(validate_file_arg("/abs/path/to/report.pdf"))
})

test_that("validate_file_arg passes for relative path ending in .pdf", {
  expect_no_error(validate_file_arg("../results/figure1.pdf"))
})

# coerce_x_to_pagelist ---------------------------------------------------------

test_that("coerce_x_to_pagelist wraps single ggplot in list(list(figure = x))", {
  p      <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  result <- coerce_x_to_pagelist(p)
  expect_type(result, "list")
  expect_length(result, 1)
  expect_type(result[[1]], "list")
  expect_true(inherits(result[[1]]$figure, "ggplot"))
})

test_that("coerce_x_to_pagelist passes through a valid list of page lists", {
  p    <- ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) + ggplot2::geom_point()
  x    <- list(list(figure = p), list(figure = p))
  result <- coerce_x_to_pagelist(x)
  expect_length(result, 2)
})

test_that("coerce_x_to_pagelist errors if a list element has no figure", {
  x <- list(list(caption = "oops"))
  expect_error(coerce_x_to_pagelist(x), regexp = "figure")
})

test_that("coerce_x_to_pagelist errors if figure is not a ggplot", {
  x <- list(list(figure = "not a plot"))
  expect_error(coerce_x_to_pagelist(x))
})

# build_page_args --------------------------------------------------------------

test_that("build_page_args page_list wins over dots for same key", {
  page_list <- list(caption = "page caption")
  dots      <- list(caption = "default caption")
  result    <- build_page_args(page_list, dots, page_num = NULL, i = 1, n = 3)
  expect_equal(result$caption, "page caption")
})

test_that("build_page_args dots fills keys absent from page_list", {
  page_list <- list(caption = "page caption")
  dots      <- list(header_left = "My Report")
  result    <- build_page_args(page_list, dots, page_num = NULL, i = 1, n = 3)
  expect_equal(result$header_left, "My Report")
  expect_equal(result$caption,     "page caption")
})

test_that("build_page_args page_num fills footer_right when absent", {
  result <- build_page_args(list(), list(), page_num = "Page {i} of {n}", i = 2, n = 5)
  expect_equal(result$footer_right, "Page 2 of 5")
})

test_that("build_page_args page_list footer_right overrides page_num", {
  page_list <- list(footer_right = "Appendix A")
  result    <- build_page_args(page_list, list(),
                               page_num = "Page {i} of {n}", i = 1, n = 3)
  expect_equal(result$footer_right, "Appendix A")
})

test_that("build_page_args dots footer_right overrides page_num", {
  dots   <- list(footer_right = "Confidential")
  result <- build_page_args(list(), dots,
                            page_num = "Page {i} of {n}", i = 1, n = 3)
  expect_equal(result$footer_right, "Confidential")
})

test_that("build_page_args with NULL page_num does not set footer_right", {
  result <- build_page_args(list(), list(), page_num = NULL, i = 1, n = 1)
  expect_null(result$footer_right)
})
