# Extracted from test-export_tfl_multi.R:295

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
files <- file.path(dir, c("ok1.pdf", "bad.pdf", "ok2.pdf", "bad2.pdf"))
too_wide <- data.frame(a = strrep("x", 400))
err <- tryCatch(
    export_tfl(
      list(ok1 = tfl_table(tbl_short), bad = tfl_table(too_wide), ok2 = make_fig(), bad2 = tfl_table(too_wide)),
      files
    ),
    error = function(e) e
  )
expect_s3_class(err, "writetfl_error_export_failed")
msg <- conditionMessage(err)
expect_match(msg, "2 of 4 PDFs failed")
