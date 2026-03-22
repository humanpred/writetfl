# test-export_tfl.R — Tests for export_tfl.R
#
# End-to-end smoke tests are in test-integration.R.  This file covers
# edge-case branches specific to export_tfl().

library(ggplot2)

# ---------------------------------------------------------------------------
# File validation
# ---------------------------------------------------------------------------

test_that("export_tfl errors on missing file when preview = FALSE", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_error(export_tfl(p), "file must be a single character")
})

test_that("export_tfl skips file validation when preview = TRUE", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  # file not supplied, but preview = TRUE should not error
  expect_no_error(export_tfl(p, preview = TRUE))
})

# ---------------------------------------------------------------------------
# Return value
# ---------------------------------------------------------------------------

test_that("export_tfl returns invisible normalized path in normal mode", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  result <- export_tfl(p, f)
  expect_equal(result, normalizePath(f, mustWork = FALSE))
})

test_that("export_tfl returns invisible NULL in preview mode", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  result <- export_tfl(p, preview = TRUE)
  expect_null(result)
})

# ---------------------------------------------------------------------------
# Preview mode page selection
# ---------------------------------------------------------------------------

test_that("export_tfl preview with out-of-range pages aborts", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  expect_error(export_tfl(p, preview = 99L), "out of range")
})

test_that("export_tfl preview with integer vector renders selected pages", {
  p1 <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  p2 <- ggplot(data.frame(x = 2, y = 2), aes(x, y)) + geom_point()
  pages <- list(list(content = p1), list(content = p2))

  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  expect_no_error(export_tfl(pages, preview = c(1L, 2L)))
})

# ---------------------------------------------------------------------------
# Device lifecycle — device closes on error
# ---------------------------------------------------------------------------

test_that("export_tfl closes device even when a page errors", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  pages <- list(
    list(content = p),
    list(content = "not a plot")  # will error
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  dev_count_before <- length(grDevices::dev.list())
  try(export_tfl(pages, f), silent = TRUE)
  dev_count_after <- length(grDevices::dev.list())

  expect_equal(dev_count_after, dev_count_before)
})

# ---------------------------------------------------------------------------
# tfl_table coercion
# ---------------------------------------------------------------------------

test_that("export_tfl handles tfl_table input", {
  df <- data.frame(a = 1:3, b = letters[1:3])
  tbl <- tfl_table(df)
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
  expect_gt(file.info(f)$size, 0)
})

# ---------------------------------------------------------------------------
# Page argument merging
# ---------------------------------------------------------------------------

test_that("export_tfl passes dots to export_tfl_page as defaults", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  expect_no_error(
    export_tfl(list(list(content = p)), f,
      header_left  = "Shared header",
      footer_right = "Shared footer"
    )
  )
  expect_true(file.exists(f))
})
