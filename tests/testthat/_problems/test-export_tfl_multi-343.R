# Extracted from test-export_tfl_multi.R:343

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

# test -------------------------------------------------------------------------
dir <- withr::local_tempdir()
expect_error(
    export_tfl(list(tfl_table(tbl_short)), file.path(dir, "a.pdf"), workers = 2),
    "`workers` is only used when `file` has one path per element"
  )
files <- file.path(dir, c("a.pdf", "b.pdf"))
x <- list(tfl_table(tbl_short), make_fig())
for (bad in list(0, 1.5, NA_real_, "2", c(2, 3), TRUE)) {
    expect_error(export_tfl(x, files, workers = bad), "`workers` must be NULL, a whole number, or a cluster", info = format(bad))
  }
