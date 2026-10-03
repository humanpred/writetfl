# Extracted from test-export_tfl_multi.R:432

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "writetfl", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
library(ggplot2)
tbl_long  <- data.frame(a = 1:60, b = letters[rep(1:6, 10)])
tbl_short <- data.frame(x = c("p", "q"), y = 1:2)
make_fig  <- function() ggplot(data.frame(x = 1:3, y = 1:3), aes(x, y)) + geom_point()
page_args <- function(pages, i, dots = list(), page_num = "Page {i} of {n}") {
  build_page_args(pages[[i]], dots, page_num, i, length(pages))
}
combined_pages <- function(x, dots = list(), page_num = "Page {i} of {n}") {
  cache <- new.env(hash = TRUE, parent = emptyenv())
  md <- .open_metric_device(NULL, 11, 8.5, preview = TRUE)
  on.exit(.close_metric_device(md))
  .elements_to_pagelist(x, 11, 8.5, dots, page_num, cache)
}
skip_if_dev_loaded <- function() {
  testthat::skip_if(
    exists(".__DEVTOOLS__", envir = asNamespace("writetfl")),
    "workers load the installed writetfl, not the devtools::load_all() copy"
  )
  testthat::skip_on_cran()
}

# test -------------------------------------------------------------------------
dir <- normalizePath(withr::local_tempdir())
dir.create(file.path(dir, "sub"))
expected <- paste0(dir, .Platform$file.sep, "a.pdf")
expect_equal(.normalize_output_path(file.path(dir, "a.pdf")), expected)
expect_equal(.normalize_output_path(file.path(dir, ".", "a.pdf")), expected)
expect_equal(.normalize_output_path(file.path(dir, "sub", "..", "a.pdf")), expected)
expect_equal(.normalize_output_path(file.path(dir, "not-yet.pdf")), paste0(dir, .Platform$file.sep, "not-yet.pdf"))
root <- normalizePath(.Platform$file.sep)
expect_equal(.normalize_output_path(paste0(root, "a.pdf")), paste0(root, "a.pdf"))
