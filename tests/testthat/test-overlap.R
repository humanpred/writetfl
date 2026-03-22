test_that("check_overlap returns no errors when content fits comfortably", {
  widths <- list(left = 1, center = 1, right = 1)
  # vp_width = 8 inches: left(1) + center/2(0.5) = 1.5 < 4 ✓
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_length(errors, 0)
})

test_that("check_overlap errors when left and center overlap", {
  # left = 3.6, center = 1, vp_width = 8: 3.6 + 0.5 = 4.1 > 4.0 → error
  widths <- list(left = 3.6, center = 1, right = 0.5)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_true(any(grepl("header_left.*header_center|left.*center", errors, ignore.case = TRUE)))
})

test_that("check_overlap errors when right and center overlap", {
  widths <- list(left = 0.5, center = 1, right = 3.6)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_true(any(grepl("header_right.*header_center|right.*center", errors, ignore.case = TRUE)))
})

test_that("check_overlap errors when left and right overlap with no center", {
  widths <- list(left = 5, center = NULL, right = 4)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_true(any(grepl("header_left.*header_right|left.*right", errors, ignore.case = TRUE)))
})

test_that("check_overlap warns on left/center near-miss within overlap_warn_mm", {
  # left = 3.4, center = 1, vp = 8: gap = 4.0 - 3.4 - 0.5 = 0.1 in = 2.54 mm
  # with warn threshold 3mm, this should warn but not error
  widths <- list(left = 3.4, center = 1, right = 0.5)
  expect_warning(
    errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 3),
    regexp = "near"
  )
  expect_length(errors, 0)
})

test_that("check_overlap warns on right/center near-miss within overlap_warn_mm", {
  # right = 3.4, center = 1, vp = 8: gap = 4.0 - 3.4 - 0.5 = 0.1 in = 2.54 mm
  # with warn threshold 3mm, this should warn but not error
  widths <- list(left = 0.5, center = 1, right = 3.4)
  expect_warning(
    errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 3),
    regexp = "near"
  )
  expect_length(errors, 0)
})

test_that("check_overlap does not warn when gap is >= overlap_warn_mm", {
  widths <- list(left = 1, center = 1, right = 1)
  expect_no_warning(
    check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  )
})

test_that("check_overlap skips all checks when overlap_warn_mm is NULL", {
  # Would normally error — but NULL disables detection
  widths <- list(left = 5, center = 2, right = 5)
  expect_no_warning(
    errors <- check_overlap(widths, vp_width_in = 4, overlap_warn_mm = NULL)
  )
  expect_length(errors, 0)
})

test_that("check_overlap handles absent center element", {
  widths <- list(left = 1, center = NULL, right = 1)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_length(errors, 0)
})

test_that("check_overlap handles all three elements absent", {
  widths <- list(left = NULL, center = NULL, right = NULL)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_length(errors, 0)
})

test_that("check_overlap handles only left present", {
  widths <- list(left = 3, center = NULL, right = NULL)
  errors <- check_overlap(widths, vp_width_in = 8, overlap_warn_mm = 2)
  expect_length(errors, 0)
})
