# test-grob_builders.R — Tests for grob_builders.R
#
# build_text_grob() and build_section_grobs() are exercised end-to-end by
# test-integration.R.  This file covers edge-case branches.

# ---------------------------------------------------------------------------
# build_text_grob() — NULL handling and basic output
# ---------------------------------------------------------------------------

test_that("build_text_grob returns NULL when norm$text is NULL", {
  norm <- list(text = NULL, nlines = 0L)
  result <- build_text_grob(norm, grid::gpar(), x_npc = 0, just = c("left", "top"))
  expect_null(result)
})

test_that("build_text_grob returns a textGrob for non-NULL text", {
  norm <- list(text = "hello", nlines = 1L)
  g <- build_text_grob(norm, grid::gpar(), x_npc = 0.5, just = c("center", "top"))
  expect_true(inherits(g, "grob"))
  expect_equal(g$label, "hello")
})

test_that("build_text_grob uses resolved_gp", {
  norm <- list(text = "bold text", nlines = 1L)
  gp <- grid::gpar(fontface = "bold", fontsize = 14)
  g <- build_text_grob(norm, gp, x_npc = 1, just = c("right", "bottom"))
  # gpar() converts fontface to font internally; check fontsize directly
  expect_equal(g$gp$fontsize, 14)
  expect_equal(unname(g$gp$font), 2L)  # 2L = bold
})

# ---------------------------------------------------------------------------
# build_section_grobs() — correct element mapping
# ---------------------------------------------------------------------------

test_that("build_section_grobs maps all 8 elements correctly", {
  norms <- list(
    header_left   = normalize_text("HL"),
    header_center = normalize_text("HC"),
    header_right  = normalize_text("HR"),
    caption       = normalize_text("Cap"),
    footnote      = normalize_text("Fn"),
    footer_left   = normalize_text("FL"),
    footer_center = normalize_text("FC"),
    footer_right  = normalize_text("FR")
  )
  gps <- lapply(norms, function(x) grid::gpar())

  result <- build_section_grobs(norms, gps, "left", "left")

  expect_true(inherits(result$header_left,   "grob"))
  expect_true(inherits(result$header_center, "grob"))
  expect_true(inherits(result$header_right,  "grob"))
  expect_true(inherits(result$caption,       "grob"))
  expect_true(inherits(result$footnote,      "grob"))
  expect_true(inherits(result$footer_left,   "grob"))
  expect_true(inherits(result$footer_center, "grob"))
  expect_true(inherits(result$footer_right,  "grob"))
})

test_that("build_section_grobs returns NULL for absent elements", {
  norms <- list(
    header_left   = normalize_text(NULL),
    header_center = normalize_text(NULL),
    header_right  = normalize_text(NULL),
    caption       = normalize_text(NULL),
    footnote      = normalize_text(NULL),
    footer_left   = normalize_text(NULL),
    footer_center = normalize_text(NULL),
    footer_right  = normalize_text(NULL)
  )
  gps <- lapply(norms, function(x) grid::gpar())

  result <- build_section_grobs(norms, gps, "left", "left")

  for (nm in names(result)) {
    expect_null(result[[nm]], info = paste(nm, "should be NULL"))
  }
})

test_that("build_section_grobs uses caption_just and footnote_just", {
  norms <- list(
    header_left   = normalize_text(NULL),
    header_center = normalize_text(NULL),
    header_right  = normalize_text(NULL),
    caption       = normalize_text("Caption"),
    footnote      = normalize_text("Footnote"),
    footer_left   = normalize_text(NULL),
    footer_center = normalize_text(NULL),
    footer_right  = normalize_text(NULL)
  )
  gps <- lapply(norms, function(x) grid::gpar())

  result <- build_section_grobs(norms, gps, "center", "right")

  expect_equal(result$caption$just,  c("center", "top"))
  expect_equal(result$footnote$just, c("right", "bottom"))
})
