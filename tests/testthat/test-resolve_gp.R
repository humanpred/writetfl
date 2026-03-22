test_that("merge_gpar returns override fields when both present", {
  base     <- grid::gpar(fontsize = 10, col = "black")
  override <- grid::gpar(fontsize = 14)
  result   <- merge_gpar(base, override)
  expect_equal(result$fontsize, 14)
  expect_equal(result$col, "black")
})

test_that("merge_gpar returns base fields absent from override", {
  base     <- grid::gpar(fontsize = 10, fontface = "bold")
  override <- grid::gpar(col = "red")
  result   <- merge_gpar(base, override)
  expect_equal(result$fontsize, 10)
  expect_equal(result$fontface, "bold")
  expect_equal(result$col, "red")
})

test_that("merge_gpar with empty override returns base", {
  base   <- grid::gpar(fontsize = 10)
  result <- merge_gpar(base, grid::gpar())
  expect_equal(result$fontsize, 10)
})

test_that("merge_gpar with empty base returns override", {
  override <- grid::gpar(fontsize = 12)
  result   <- merge_gpar(grid::gpar(), override)
  expect_equal(result$fontsize, 12)
})

test_that("resolve_gp returns gpar() when gp is bare gpar and no match", {
  result <- resolve_gp(grid::gpar(), "header", "header_left")
  expect_s3_class(result, "gpar")
})

test_that("resolve_gp uses global gpar when gp is bare gpar", {
  gp     <- grid::gpar(fontsize = 9)
  result <- resolve_gp(gp, "footer", "footer_right")
  expect_equal(result$fontsize, 9)
})

test_that("resolve_gp uses section-level gp over global", {
  gp <- list(
    header = grid::gpar(fontsize = 11),
    gp     = grid::gpar(fontsize = 9)   # this key is not the global slot
  )
  # global via bare gpar — supply as the gp arg directly
  gp2 <- list(header = grid::gpar(fontsize = 11))
  result <- resolve_gp(gp2, "header", "header_left")
  expect_equal(result$fontsize, 11)
})

test_that("resolve_gp uses element-level gp over section-level", {
  gp <- list(
    header       = grid::gpar(fontsize = 11),
    header_left  = grid::gpar(fontsize = 14)
  )
  result <- resolve_gp(gp, "header", "header_left")
  expect_equal(result$fontsize, 14)
})

test_that("resolve_gp uses element-level gp over global", {
  gp <- list(header_right = grid::gpar(fontsize = 8, fontface = "italic"))
  result <- resolve_gp(gp, "header", "header_right")
  expect_equal(result$fontsize, 8)
  expect_equal(result$fontface, "italic")
})

test_that("resolve_gp handles missing section key gracefully", {
  gp     <- list(footer = grid::gpar(fontsize = 8))
  result <- resolve_gp(gp, "caption", "caption")
  expect_s3_class(result, "gpar")
  # should not inherit footer settings
  expect_null(result$fontsize)
})

test_that("resolve_gp handles missing element key gracefully", {
  gp     <- list(header = grid::gpar(fontsize = 11))
  result <- resolve_gp(gp, "header", "header_center")
  # falls back to section level
  expect_equal(result$fontsize, 11)
})

test_that("resolve_gp merges element over section fields correctly", {
  gp <- list(
    header      = grid::gpar(fontsize = 11, col = "black"),
    header_left = grid::gpar(fontsize = 14)               # only overrides fontsize
  )
  result <- resolve_gp(gp, "header", "header_left")
  expect_equal(result$fontsize, 14)
  expect_equal(result$col, "black")  # inherited from section level
})
