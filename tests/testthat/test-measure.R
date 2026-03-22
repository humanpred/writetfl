# test-measure.R — Tests for R/measure.R

# measure_grob_width() --------------------------------------------------------

test_that("measure_grob_width returns 0 for NULL grob", {
  expect_equal(writetfl:::measure_grob_width(NULL), 0)
})

test_that("measure_grob_width returns positive width for a real text grob", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) }, add = TRUE)

  vp <- grid::viewport(width  = grid::unit(10, "inches"),
                       height = grid::unit(7.5, "inches"))
  grid::pushViewport(vp)
  grob <- grid::textGrob("Hello world", gp = grid::gpar(fontsize = 12))
  w    <- writetfl:::measure_grob_width(grob)
  grid::popViewport()
  expect_gt(w, 0)
})
