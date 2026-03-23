# Tests for R/table1.R — table1 connector

skip_if_not_installed("table1")
skip_if_not_installed("flextable")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

make_test_data <- function(n = 30) {
  set.seed(42)
  dat <- data.frame(
    age = rnorm(n, 50, 10),
    sex = sample(c("Male", "Female"), n, replace = TRUE),
    bmi = rnorm(n, 25, 4),
    trt = rep(c("Treatment", "Placebo"), length.out = n),
    stringsAsFactors = FALSE
  )
  table1::label(dat$age) <- "Age (years)"
  table1::label(dat$sex) <- "Sex"
  table1::label(dat$bmi) <- "BMI (kg/m\u00b2)"
  dat
}

make_simple_t1 <- function(caption = NULL, footnote = NULL) {
  dat <- make_test_data()
  table1::table1(~ age + sex, data = dat,
                 caption = caption, footnote = footnote)
}

make_stratified_t1 <- function(caption = NULL, footnote = NULL) {
  dat <- make_test_data()
  table1::table1(~ age + sex | trt, data = dat,
                 caption = caption, footnote = footnote)
}

# ---------------------------------------------------------------------------
# .extract_table1_annotations()
# ---------------------------------------------------------------------------

test_that(".extract_table1_annotations extracts caption only", {
  t1 <- make_simple_t1(caption = "Table 1. Demographics")
  annot <- .extract_table1_annotations(t1)
  expect_equal(annot$caption, "Table 1. Demographics")
  expect_null(annot$footnote)
})

test_that(".extract_table1_annotations extracts footnote only", {
  t1 <- make_simple_t1(footnote = "ITT Population")
  annot <- .extract_table1_annotations(t1)
  expect_null(annot$caption)
  expect_equal(annot$footnote, "ITT Population")
})

test_that(".extract_table1_annotations extracts both caption and footnote", {
  t1 <- make_simple_t1(caption = "Demographics", footnote = "Note 1")
  annot <- .extract_table1_annotations(t1)
  expect_equal(annot$caption, "Demographics")
  expect_equal(annot$footnote, "Note 1")
})

test_that(".extract_table1_annotations handles no annotations", {
  t1 <- make_simple_t1()
  annot <- .extract_table1_annotations(t1)
  expect_null(annot$caption)
  expect_null(annot$footnote)
})

test_that(".extract_table1_annotations handles multiple footnotes", {
  t1 <- make_simple_t1(footnote = c("Note 1", "Note 2"))
  annot <- .extract_table1_annotations(t1)
  expect_equal(annot$footnote, "Note 1\nNote 2")
})

test_that(".extract_table1_annotations handles empty caption", {
  t1 <- make_simple_t1(caption = "")
  annot <- .extract_table1_annotations(t1)
  expect_null(annot$caption)
})

test_that(".extract_table1_annotations handles empty footnote", {
  t1 <- make_simple_t1(footnote = "")
  annot <- .extract_table1_annotations(t1)
  expect_null(annot$footnote)
})

# ---------------------------------------------------------------------------
# .table1_variable_groups()
# ---------------------------------------------------------------------------

test_that(".table1_variable_groups identifies two-variable groups", {
  t1 <- make_simple_t1()
  groups <- .table1_variable_groups(t1)
  expect_length(groups, 2L)
  # Each group should start at the right row
  expect_equal(groups[[1]][1], 1L)
  # Groups should be contiguous and cover all rows
  all_rows <- unlist(groups)
  expect_equal(all_rows, seq_along(all_rows))
})

test_that(".table1_variable_groups identifies three-variable groups", {
  dat <- make_test_data()
  t1 <- table1::table1(~ age + sex + bmi, data = dat)
  groups <- .table1_variable_groups(t1)
  expect_length(groups, 3L)
  all_rows <- unlist(groups)
  expect_equal(all_rows, seq_along(all_rows))
})

test_that(".table1_variable_groups works with stratification", {
  t1 <- make_stratified_t1()
  groups <- .table1_variable_groups(t1)
  expect_length(groups, 2L)
  # Stratification doesn't affect the number of variable groups
})

# ---------------------------------------------------------------------------
# table1_to_pagelist() — single page
# ---------------------------------------------------------------------------

test_that("table1_to_pagelist returns single page for small table", {
  t1 <- make_simple_t1(caption = "Demographics")
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
  expect_equal(pages[[1]]$caption, "Demographics")
})

test_that("table1_to_pagelist includes footnote in page spec", {
  t1 <- make_simple_t1(caption = "Demographics", footnote = "Safety set")
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_equal(pages[[1]]$caption, "Demographics")
  expect_equal(pages[[1]]$footnote, "Safety set")
})

test_that("table1_to_pagelist works without annotations", {
  t1 <- make_simple_t1()
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
  expect_null(pages[[1]]$caption)
  expect_null(pages[[1]]$footnote)
})

test_that("table1_to_pagelist preserves column labels", {
  # Verify the flextable grob is created — column labels are part of the

  # flextable header, which t1flex() preserves
  dat <- make_test_data()
  t1 <- table1::table1(~ age + sex | trt, data = dat)
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
})

# ---------------------------------------------------------------------------
# End-to-end: export_tfl() with table1 input
# ---------------------------------------------------------------------------

test_that("export_tfl writes PDF from table1 object", {
  t1 <- make_stratified_t1(caption = "Table 1. Demographics")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  result <- export_tfl(t1, file = tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 0)
  expect_equal(result, normalizePath(tmp, mustWork = FALSE))
})

test_that("export_tfl preview mode works with table1", {
  t1 <- make_stratified_t1(caption = "Demographics")
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(t1, preview = TRUE,
                       header_left = "Study Report",
                       header_rule = TRUE, footer_rule = TRUE)
  expect_null(result)
})

test_that("export_tfl preview = c(1) works with table1", {
  t1 <- make_stratified_t1(caption = "Demographics")
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(t1, preview = 1,
                       header_left = "Study Report")
  expect_null(result)
})

test_that("export_tfl passes page layout args for table1", {
  t1 <- make_stratified_t1()
  tmp <- withr::local_tempfile(fileext = ".pdf")
  result <- export_tfl(t1, file = tmp,
                       header_left = "Protocol XY-001",
                       header_right = "2025-01-01",
                       footnote = "Safety population",
                       header_rule = TRUE,
                       footer_rule = TRUE)
  expect_true(file.exists(tmp))
})

# ---------------------------------------------------------------------------
# List of table1 objects
# ---------------------------------------------------------------------------

test_that("export_tfl handles list of table1 objects", {
  dat <- make_test_data()
  t1a <- table1::table1(~ age | trt, data = dat, caption = "Age Summary")
  t1b <- table1::table1(~ sex | trt, data = dat, caption = "Sex Summary")
  tmp <- withr::local_tempfile(fileext = ".pdf")
  result <- export_tfl(list(t1a, t1b), file = tmp)
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 0)
})

test_that("export_tfl preview with list of table1 objects", {
  dat <- make_test_data()
  t1a <- table1::table1(~ age, data = dat)
  t1b <- table1::table1(~ sex, data = dat)
  grDevices::pdf(NULL, width = 11, height = 8.5)
  on.exit(grDevices::dev.off(), add = TRUE)
  result <- export_tfl(list(t1a, t1b), preview = TRUE)
  expect_null(result)
})

# ---------------------------------------------------------------------------
# S3 dispatch
# ---------------------------------------------------------------------------

test_that("S3 dispatch works for table1 class", {
  t1 <- make_simple_t1()
  expect_true(inherits(t1, "table1"))
  # Verify it dispatches to export_tfl.table1 (not default)
  tmp <- withr::local_tempfile(fileext = ".pdf")
  # Should not error — default method would fail since table1 is not grob/ggplot

  expect_no_error(export_tfl(t1, file = tmp))
})

test_that("S3 dispatch works for list of table1 objects", {
  dat <- make_test_data()
  t1_list <- list(
    table1::table1(~ age, data = dat),
    table1::table1(~ sex, data = dat)
  )
  tmp <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(export_tfl(t1_list, file = tmp))
})

# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------

test_that("table1_to_pagelist paginates tall tables", {
  # Create a table with many variables to force pagination
  set.seed(42)
  dat <- data.frame(
    v01 = rnorm(50), v02 = rnorm(50), v03 = rnorm(50),
    v04 = rnorm(50), v05 = rnorm(50), v06 = rnorm(50),
    v07 = rnorm(50), v08 = rnorm(50), v09 = rnorm(50),
    v10 = rnorm(50), v11 = rnorm(50), v12 = rnorm(50),
    v13 = rnorm(50), v14 = rnorm(50), v15 = rnorm(50),
    v16 = rnorm(50), v17 = rnorm(50), v18 = rnorm(50),
    v19 = rnorm(50), v20 = rnorm(50)
  )
  for (v in names(dat)) table1::label(dat[[v]]) <- paste("Variable", v)
  t1 <- table1::table1(
    ~ v01 + v02 + v03 + v04 + v05 + v06 + v07 + v08 + v09 + v10 +
      v11 + v12 + v13 + v14 + v15 + v16 + v17 + v18 + v19 + v20,
    data = dat,
    caption = "Big Table",
    footnote = "Test footnote"
  )

  # Use small page to force pagination
  pages <- table1_to_pagelist(t1, pg_height = 5)
  expect_gt(length(pages), 1L)
  # All pages should have content, caption, and footnote
  for (pg in pages) {
    expect_true(inherits(pg$content, "grob"))
    expect_equal(pg$caption, "Big Table")
    expect_equal(pg$footnote, "Test footnote")
  }
})

test_that("table1_to_pagelist end-to-end PDF with pagination", {
  set.seed(42)
  dat <- data.frame(
    v01 = rnorm(50), v02 = rnorm(50), v03 = rnorm(50),
    v04 = rnorm(50), v05 = rnorm(50), v06 = rnorm(50),
    v07 = rnorm(50), v08 = rnorm(50), v09 = rnorm(50),
    v10 = rnorm(50), v11 = rnorm(50), v12 = rnorm(50)
  )
  for (v in names(dat)) table1::label(dat[[v]]) <- paste("Var", v)
  t1 <- table1::table1(
    ~ v01 + v02 + v03 + v04 + v05 + v06 + v07 + v08 + v09 + v10 +
      v11 + v12,
    data = dat, caption = "Many Variables"
  )
  tmp <- withr::local_tempfile(fileext = ".pdf")
  result <- export_tfl(t1, file = tmp, pg_height = 5)
  expect_true(file.exists(tmp))
  expect_gt(file.size(tmp), 0)
})

# ---------------------------------------------------------------------------
# Stratification features
# ---------------------------------------------------------------------------

test_that("table1_to_pagelist handles stratified tables", {
  t1 <- make_stratified_t1(caption = "Stratified Table")
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_equal(pages[[1]]$caption, "Stratified Table")
})

test_that("table1_to_pagelist handles overall column", {
  dat <- make_test_data()
  t1 <- table1::table1(~ age + sex | trt, data = dat, overall = "Total")
  pages <- table1_to_pagelist(t1)
  expect_length(pages, 1L)
  expect_true(inherits(pages[[1]]$content, "grob"))
})

# ---------------------------------------------------------------------------
# .paginate_table1() — direct tests
# ---------------------------------------------------------------------------

test_that(".paginate_table1 splits between variable groups", {
  # Use a table with many variables and convert to flextable
  set.seed(42)
  dat <- data.frame(
    v01 = rnorm(50), v02 = rnorm(50), v03 = rnorm(50),
    v04 = rnorm(50), v05 = rnorm(50), v06 = rnorm(50),
    v07 = rnorm(50), v08 = rnorm(50), v09 = rnorm(50),
    v10 = rnorm(50)
  )
  for (v in names(dat)) table1::label(dat[[v]]) <- paste("Var", v)
  t1 <- table1::table1(
    ~ v01 + v02 + v03 + v04 + v05 + v06 + v07 + v08 + v09 + v10,
    data = dat
  )

  groups <- .table1_variable_groups(t1)
  ft <- table1::t1flex(t1)
  ft <- .clean_flextable(ft)
  ft$caption <- list(value = NULL)

  # Small content_h to force multiple pages
  content_w <- 10
  content_h <- 2.5

  ft_pages <- .paginate_table1(ft, groups, content_h, content_w)
  expect_gt(length(ft_pages), 1L)
  # Each page should be a flextable
 for (pg in ft_pages) {
    expect_true(inherits(pg, "flextable"))
  }
})

test_that(".paginate_table1 keeps small table as single page", {
  t1 <- make_simple_t1()
  groups <- .table1_variable_groups(t1)
  ft <- table1::t1flex(t1)
  ft <- .clean_flextable(ft)
  ft$caption <- list(value = NULL)

  content_w <- 10
  content_h <- 10  # Very large — everything fits

  ft_pages <- .paginate_table1(ft, groups, content_h, content_w)
  expect_length(ft_pages, 1L)
})

# ---------------------------------------------------------------------------
# .paginate_oversized_group() — direct tests
# ---------------------------------------------------------------------------

test_that(".paginate_oversized_group splits a large group row-by-row", {
  # Create a table with one variable that has many categories
  set.seed(42)
  # Use a factor with many levels for a single variable
  dat <- data.frame(
    category = factor(sample(LETTERS[1:20], 100, replace = TRUE))
  )
  table1::label(dat$category) <- "Category"
  t1 <- table1::table1(~ category, data = dat)

  groups <- .table1_variable_groups(t1)
  ft <- table1::t1flex(t1)
  ft <- .clean_flextable(ft)
  ft$caption <- list(value = NULL)

  content_w <- 10

  # Very small content_h to force oversized group splitting
  content_h <- 1.5

  # The single group should be split
  results <- .paginate_oversized_group(ft, groups[[1]], content_h, content_w)
  expect_gt(length(results), 1L)
  # All but the last should be flextable objects
  for (i in seq_along(results)) {
    if (i < length(results)) {
      expect_true(inherits(results[[i]], "flextable"))
    } else {
      # Last element is a list with $body_rows
      expect_true(is.list(results[[i]]))
      expect_true("body_rows" %in% names(results[[i]]))
    }
  }
})

test_that(".paginate_table1 handles oversized first group", {
  # Create a table where the first variable has many categories
  set.seed(42)
  dat <- data.frame(
    big_cat = factor(sample(LETTERS[1:20], 100, replace = TRUE)),
    small = rnorm(100)
  )
  table1::label(dat$big_cat) <- "Big Category"
  table1::label(dat$small) <- "Small Variable"
  t1 <- table1::table1(~ big_cat + small, data = dat)

  groups <- .table1_variable_groups(t1)
  ft <- table1::t1flex(t1)
  ft <- .clean_flextable(ft)
  ft$caption <- list(value = NULL)

  content_w <- 10
  content_h <- 1.5  # Very small to force oversized first group

  ft_pages <- .paginate_table1(ft, groups, content_h, content_w)
  expect_gt(length(ft_pages), 1L)
  for (pg in ft_pages) {
    expect_true(inherits(pg, "flextable"))
  }
})

test_that(".paginate_table1 handles oversized group after accumulated rows", {
  # Mix: first groups fit, then an oversized group appears
  set.seed(42)
  dat <- data.frame(
    small1 = rnorm(100),
    small2 = rnorm(100),
    big_cat = factor(sample(LETTERS[1:15], 100, replace = TRUE))
  )
  table1::label(dat$small1) <- "Small 1"
  table1::label(dat$small2) <- "Small 2"
  table1::label(dat$big_cat) <- "Big Category"
  t1 <- table1::table1(~ small1 + small2 + big_cat, data = dat)

  groups <- .table1_variable_groups(t1)
  ft <- table1::t1flex(t1)
  ft <- .clean_flextable(ft)
  ft$caption <- list(value = NULL)

  content_w <- 10
  # Just enough for the two small groups but not big_cat
  content_h <- 2.0

  ft_pages <- .paginate_table1(ft, groups, content_h, content_w)
  expect_gt(length(ft_pages), 1L)
  for (pg in ft_pages) {
    expect_true(inherits(pg, "flextable"))
  }
})
