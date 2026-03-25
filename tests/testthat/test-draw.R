# test-draw.R — Tests for draw.R helpers
#
# Most draw functions are exercised end-to-end by test-integration.R.
# This file covers edge-case branches specific to the draw helpers.

library(ggplot2)

# ---------------------------------------------------------------------------
# draw_content() — dispatch and error handling
# ---------------------------------------------------------------------------

test_that("draw_content dispatches to grob branch for grid grob", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(5, "inches"),
                       height = grid::unit(5, "inches"))
  g <- grid::textGrob("hello")
  expect_no_error(draw_content(g, vp))
})

test_that("draw_content dispatches to ggplot branch for ggplot object", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(5, "inches"),
                       height = grid::unit(5, "inches"))
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_no_error(draw_content(p, vp))
})

test_that("draw_content dispatches to character branch for a single string", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(5, "inches"),
                       height = grid::unit(5, "inches"))
  expect_no_error(draw_content("Hello world", vp))
})

test_that("draw_content joins character vector with newlines", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(5, "inches"),
                       height = grid::unit(5, "inches"))
  expect_no_error(draw_content(c("Line one", "Line two", "Line three"), vp))
})

test_that("draw_content wraps a long character string without error", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(2, "inches"),
                       height = grid::unit(5, "inches"))
  long_str <- paste(rep("word", 50), collapse = " ")
  expect_no_error(draw_content(long_str, vp))
})

test_that("draw_content respects content_just for character content", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) })
  grid::grid.newpage()
  vp <- grid::viewport(width = grid::unit(5, "inches"),
                       height = grid::unit(5, "inches"))
  expect_no_error(draw_content("Right-aligned", vp, content_just = "right"))
  expect_no_error(draw_content("Centred", vp, content_just = "centre"))
})

test_that("draw_content errors for unsupported content type", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  vp <- grid::viewport()
  expect_error(draw_content(42L, vp), "ggplot object, a grid grob, or a character")
})

# ---------------------------------------------------------------------------
# draw_rule() — rule drawing
# ---------------------------------------------------------------------------

test_that("draw_rule returns invisible NULL for FALSE rule", {
  result <- draw_rule(FALSE, 0.5)
  expect_null(result)
})

test_that("draw_rule draws a linesGrob at the given y position", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  rule <- grid::linesGrob(
    x = grid::unit(c(0, 1), "npc"),
    y = grid::unit(c(0.5, 0.5), "npc")
  )
  expect_no_error(draw_rule(rule, 0.7))
})

# ---------------------------------------------------------------------------
# draw_header_section() / draw_footer_section() — NULL handling
# ---------------------------------------------------------------------------

test_that("draw_header_section skips NULL grobs without error", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  grobs <- list(header_left = NULL, header_center = NULL, header_right = NULL)
  expect_no_error(draw_header_section(grobs, y_top_npc = 1.0))
})

test_that("draw_footer_section skips NULL grobs without error", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  grobs <- list(footer_left = NULL, footer_center = NULL, footer_right = NULL)
  expect_no_error(draw_footer_section(grobs, y_bottom_npc = 0.0))
})

# ---------------------------------------------------------------------------
# draw_caption_section() / draw_footnote_section() — NULL handling
# ---------------------------------------------------------------------------

test_that("draw_caption_section does nothing for NULL grob", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  expect_no_error(draw_caption_section(NULL, y_top_npc = 0.9))
})

test_that("draw_footnote_section does nothing for NULL grob", {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  grid::grid.newpage()
  expect_no_error(draw_footnote_section(NULL, y_bottom_npc = 0.1))
})
