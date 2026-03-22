test_that("normalize_text returns NULL text and 0 nlines for NULL input", {
  result <- normalize_text(NULL)
  expect_null(result$text)
  expect_equal(result$nlines, 0L)
})

test_that("normalize_text handles single string", {
  result <- normalize_text("hello")
  expect_equal(result$text, "hello")
  expect_equal(result$nlines, 1L)
})

test_that("normalize_text collapses character vector with newline", {
  result <- normalize_text(c("line one", "line two"))
  expect_equal(result$text, "line one\nline two")
  expect_equal(result$nlines, 2L)
})

test_that("normalize_text counts embedded newlines in nlines", {
  result <- normalize_text("line one\nline two\nline three")
  expect_equal(result$nlines, 3L)
})

test_that("normalize_text counts lines correctly after collapsing vector with embedded newlines", {
  result <- normalize_text(c("line one\nline two", "line three"))
  expect_equal(result$nlines, 3L)
})

test_that("normalize_text handles empty string", {
  result <- normalize_text("")
  expect_equal(result$text, "")
  expect_equal(result$nlines, 1L)
})

test_that("normalize_text handles character(0)", {
  result <- normalize_text(character(0))
  expect_null(result$text)
  expect_equal(result$nlines, 0L)
})

test_that("normalize_rule returns FALSE for FALSE", {
  expect_false(normalize_rule(FALSE))
})

test_that("normalize_rule returns a linesGrob for TRUE", {
  result <- normalize_rule(TRUE)
  expect_s3_class(result, "grob")
  expect_equal(result$name |> startsWith("lines"), TRUE)
})

test_that("normalize_rule returns a centered linesGrob for numeric 0.5", {
  result <- normalize_rule(0.5)
  expect_s3_class(result, "grob")
  # x should span from 0.25 to 0.75 npc
  x_vals <- grid::convertX(result$x, "npc", valueOnly = TRUE)
  expect_equal(x_vals, c(0.25, 0.75), tolerance = 1e-6)
})

test_that("normalize_rule errors for numeric outside (0, 1]", {
  expect_error(normalize_rule(0))
  expect_error(normalize_rule(1.1))
  expect_error(normalize_rule(-0.5))
})

test_that("normalize_rule passes a linesGrob through unchanged", {
  lg <- grid::linesGrob()
  result <- normalize_rule(lg)
  expect_identical(result, lg)
})

test_that("normalize_rule errors for invalid input type", {
  expect_error(normalize_rule("thick"))
  expect_error(normalize_rule(list()))
})
