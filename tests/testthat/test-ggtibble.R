skip_if_not_installed("ggtibble")

library(ggplot2)

# Helper: create a minimal ggtibble for testing
make_test_ggtibble <- function(extra_cols = list()) {
  d <- data.frame(
    grp = c("A", "A", "B", "B"),
    x   = 1:4,
    y   = c(2, 4, 1, 3)
  )
  gt <- ggtibble::ggtibble(d, ggplot2::aes(x, y),
                            outercols = "grp",
                            caption = "Plot for group {grp}")
  gt <- gt + ggplot2::geom_point()
  # Add any extra columns
  for (nm in names(extra_cols)) {
    gt[[nm]] <- extra_cols[[nm]]
  }
  gt
}

# ggtibble_to_pagelist() ---------------------------------------------------

test_that("ggtibble_to_pagelist converts figure and caption", {
  gt    <- make_test_ggtibble()
  pages <- writetfl:::ggtibble_to_pagelist(gt)

  expect_length(pages, nrow(gt))
  for (i in seq_len(nrow(gt))) {
    expect_true(inherits(pages[[i]]$content, "gg"))
    expect_equal(pages[[i]]$caption, gt$caption[[i]])
  }
})

test_that("ggtibble_to_pagelist maps annotation columns by name", {
  gt <- make_test_ggtibble(extra_cols = list(
    header_left = c("HL1", "HL2"),
    footnote    = c("FN1", "FN2")
  ))
  pages <- writetfl:::ggtibble_to_pagelist(gt)

  expect_equal(pages[[1L]]$header_left, "HL1")
  expect_equal(pages[[2L]]$header_left, "HL2")
  expect_equal(pages[[1L]]$footnote, "FN1")
  expect_equal(pages[[2L]]$footnote, "FN2")
})

test_that("ggtibble_to_pagelist ignores non-annotation columns", {
  gt    <- make_test_ggtibble()
  pages <- writetfl:::ggtibble_to_pagelist(gt)

  # data_plot and grp should not appear in page specs
  for (pg in pages) {
    expect_null(pg$data_plot)
    expect_null(pg$grp)
  }
})

# export_tfl.ggtibble() — end-to-end --------------------------------------

test_that("export_tfl writes PDF from ggtibble", {
  gt   <- make_test_ggtibble()
  tmp  <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  result <- export_tfl(gt, file = tmp)
  expect_true(file.exists(tmp))
  expect_equal(normalizePath(result), normalizePath(tmp))
})

test_that("export_tfl preview mode works with ggtibble", {
  gt <- make_test_ggtibble()

  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)

  result <- export_tfl(gt, preview = TRUE)
  expect_null(result)
})

test_that("export_tfl.ggtibble passes dots as defaults", {
  gt  <- make_test_ggtibble()
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  # header_left via dots should not error

  expect_no_error(
    export_tfl(gt, file = tmp, header_left = "Global Header")
  )
})

test_that("per-row ggtibble columns override dots defaults", {
  gt <- make_test_ggtibble(extra_cols = list(
    header_right = c("Row HR 1", "Row HR 2")
  ))
  pages <- writetfl:::ggtibble_to_pagelist(gt)

  # The page specs should carry the per-row value

  expect_equal(pages[[1L]]$header_right, "Row HR 1")
  expect_equal(pages[[2L]]$header_right, "Row HR 2")
})

test_that("ggtibble_to_pagelist handles bare gg objects in figure column", {
  # Simulate a ggtibble where figure contains bare ggplots (not gglist)
  p1 <- ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  fake_gt <- data.frame(caption = "Cap 1")
  fake_gt$figure <- list(p1)
  class(fake_gt) <- c("ggtibble", class(fake_gt))

  pages <- writetfl:::ggtibble_to_pagelist(fake_gt)
  expect_true(inherits(pages[[1L]]$content, "gg"))
})

test_that("ggtibble_to_pagelist unwraps nested list figures", {
  # Simulate a figure column that contains list(ggplot) per row
  p1 <- ggplot2::ggplot(data.frame(x = 1, y = 1), ggplot2::aes(x, y)) +
    ggplot2::geom_point()
  fake_gt <- data.frame(caption = "Cap 1")
  fake_gt$figure <- list(list(p1))
  class(fake_gt) <- c("ggtibble", class(fake_gt))

  pages <- writetfl:::ggtibble_to_pagelist(fake_gt)
  expect_true(inherits(pages[[1L]]$content, "gg"))
})

# S3 dispatch --------------------------------------------------------------

test_that("export_tfl dispatches to ggtibble method", {
  gt  <- make_test_ggtibble()
  tmp <- tempfile(fileext = ".pdf")
  on.exit(unlink(tmp), add = TRUE)

  # Confirm S3 dispatch finds the right method
  expect_true(is.function(getS3method("export_tfl", "ggtibble")))
  expect_no_error(export_tfl(gt, file = tmp))
})
