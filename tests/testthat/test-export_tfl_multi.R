# test-export_tfl_multi.R — export_tfl() on a list of tables, figures and page
# specifications (one combined PDF), and with one path per element (one PDF
# each, optionally in parallel).
#
# No PDF text reader is a dependency, so page contents are checked on the
# pagelist that the combined export draws (.elements_to_pagelist() with
# build_page_args(), which is what each page's annotations are merged from)
# and page counts are checked on the written files with count_pdf_pages().

library(ggplot2)

tbl_long  <- data.frame(a = 1:60, b = letters[rep(1:6, 10)])
tbl_short <- data.frame(x = c("p", "q"), y = 1:2)
make_fig  <- function() ggplot(data.frame(x = 1:3, y = 1:3), aes(x, y)) + geom_point()

# The annotations page i of `pages` is drawn with.
page_args <- function(pages, i, dots = list(), page_num = "Page {i} of {n}") {
  build_page_args(pages[[i]], dots, page_num, i, length(pages))
}

# Pagelist of a combined export, as export_tfl.list() builds it.
combined_pages <- function(x, dots = list(), page_num = "Page {i} of {n}") {
  cache <- new.env(hash = TRUE, parent = emptyenv())
  md <- .open_metric_device(NULL, 11, 8.5, preview = TRUE)
  on.exit(.close_metric_device(md))
  .elements_to_pagelist(x, 11, 8.5, dots, page_num, cache)
}

# --- Combined PDF ---------------------------------------------------------------

test_that("tables and a figure are one PDF whose page count is the sum of the parts", {
  f <- withr::local_tempfile(fileext = ".pdf")
  f_long <- withr::local_tempfile(fileext = ".pdf")
  f_short <- withr::local_tempfile(fileext = ".pdf")
  f_fig <- withr::local_tempfile(fileext = ".pdf")
  export_tfl(tfl_table(tbl_long), f_long)
  export_tfl(tfl_table(tbl_short), f_short)
  export_tfl(make_fig(), f_fig)
  n_long <- count_pdf_pages(f_long)
  expect_gt(n_long, 1L)

  ret <- export_tfl(
    list(
      list(content = tfl_table(tbl_long), caption = "Table 1"),
      list(content = tfl_table(tbl_short), caption = "Table 2"),
      list(content = make_fig(), caption = "Figure 1")
    ),
    f
  )
  expect_equal(ret, normalizePath(f, mustWork = FALSE))
  expect_equal(count_pdf_pages(f), n_long + 1L + 1L)
  expect_equal(count_pdf_pages(f_short), 1L)
  expect_equal(count_pdf_pages(f_fig), 1L)
})

test_that("each page carries its own table's caption and 'Page i of n' counts over all parts", {
  pages <- combined_pages(list(
    list(content = tfl_table(tbl_long), caption = "Table 1", footnote = "Note 1"),
    list(content = tfl_table(tbl_short), caption = "Table 2"),
    list(content = make_fig(), caption = "Figure 1")
  ))
  n <- length(pages)
  n_long <- n - 2L
  expect_gt(n_long, 1L)
  captions <- vapply(seq_len(n), function(i) page_args(pages, i)$caption, character(1))
  expect_equal(captions, c(rep("Table 1", n_long), "Table 2", "Figure 1"))
  footers <- vapply(seq_len(n), function(i) page_args(pages, i)$footer_right, character(1))
  expect_equal(footers, sprintf("Page %d of %d", seq_len(n), n))
  footnotes <- lapply(seq_len(n), function(i) page_args(pages, i)$footnote)
  expect_equal(footnotes, c(rep(list("Note 1"), n_long), list(NULL, NULL)))
})

test_that("a table without a page specification takes the call-level annotations, and a specification overrides them", {
  pages <- combined_pages(
    list(
      tfl_table(tbl_short),
      list(content = tfl_table(tbl_short), caption = "Own caption", header_left = "Own header")
    ),
    dots = list(caption = "Shared caption", header_left = "Shared header")
  )
  expect_length(pages, 2L)
  a1 <- page_args(pages, 1, dots = list(caption = "Shared caption", header_left = "Shared header"))
  a2 <- page_args(pages, 2, dots = list(caption = "Shared caption", header_left = "Shared header"))
  expect_equal(c(a1$caption, a1$header_left), c("Shared caption", "Shared header"))
  expect_equal(c(a2$caption, a2$header_left), c("Own caption", "Own header"))
})

test_that("a specification's layout arguments apply to its own table's pagination and pages only", {
  wide_margins <- grid::unit(c(t = 3, r = 0.5, b = 3, l = 0.5), "inches")
  pages_default <- combined_pages(list(tfl_table(tbl_long)))
  pages_spec <- combined_pages(list(
    list(content = tfl_table(tbl_long), margins = wide_margins),
    tfl_table(tbl_short)
  ))
  n_spec_long <- length(pages_spec) - 1L
  # Tighter vertical space means more pages for the same table.
  expect_gt(n_spec_long, length(pages_default))
  expect_equal(pages_spec[[1]]$margins, wide_margins)
  expect_null(pages_spec[[length(pages_spec)]]$margins)
})

test_that("sub_tfl captions keep the specification's caption as their prefix", {
  d <- data.frame(g = c("u", "u", "v"), v = 1:3)
  pages <- combined_pages(list(
    list(content = tfl_table(d, sub_tfl = "g"), caption = "By group")
  ))
  expect_length(pages, 2L)
  captions <- vapply(pages, function(pg) pg$caption, character(1))
  expect_match(captions[[1]], "^By group")
  expect_match(captions[[1]], "g: u")
  expect_match(captions[[2]], "g: v")
})

test_that("an unnamed list of parts is flattened in order", {
  pages <- combined_pages(list(
    list(list(content = tfl_table(tbl_short), caption = "A"), list(content = make_fig(), caption = "B")),
    list(content = tfl_table(tbl_short), caption = "C")
  ))
  captions <- vapply(seq_along(pages), function(i) page_args(pages, i)$caption, character(1))
  expect_equal(captions, c("A", "B", "C"))
})

test_that("a bare ggplot or grob element is a page", {
  pages <- combined_pages(list(make_fig(), grid::textGrob("hi"), tfl_table(tbl_short)))
  expect_length(pages, 3L)
})

test_that("a tfl_table with an NA caption in its specification is drawn without a caption", {
  x <- list(list(content = tfl_table(tbl_short), caption = NA_character_))
  caption <- page_args(combined_pages(x), 1)$caption
  expect_true(is.null(caption) || .is_single_na(caption))
  f <- withr::local_tempfile(fileext = ".pdf")
  expect_no_error(export_tfl(x, f))
  expect_equal(count_pdf_pages(f), 1L)
})

test_that("lists that export_tfl() already accepted are unchanged", {
  f <- withr::local_tempfile(fileext = ".pdf")
  expect_equal(
    export_tfl(list(list(content = make_fig(), caption = "A"), list(content = make_fig())), f),
    normalizePath(f, mustWork = FALSE)
  )
  expect_equal(count_pdf_pages(f), 2L)
  expect_error(export_tfl(list(list(foo = 1)), f), "x\\[\\[1\\]\\] must contain a 'content' element")
  expect_error(
    export_tfl(list(list(content = 1)), f),
    "x\\$content must be a ggplot object, a grid grob, or a character string/vector"
  )
})

test_that("an element that is none of a table, figure, grob, or page specification is an error", {
  f <- withr::local_tempfile(fileext = ".pdf")
  devices_before <- length(grDevices::dev.list())
  expect_error(export_tfl(list(tfl_table(tbl_short), 1), f),"x\\[\\[2\\]\\] must be a tfl_table")
  expect_error(export_tfl(list(tfl_table(tbl_short), NULL), f), "x\\[\\[2\\]\\] must be a tfl_table")
  expect_error(
    export_tfl(list(tfl_table(tbl_short), list(list(content = 1), 2)), f),
    "x\\[\\[2\\]\\] must be a tfl_table"
  )
  # Relative to the devices other tests left open: the call closes what it opened.
  expect_equal(length(grDevices::dev.list()), devices_before)
})

test_that("a combined export of tables opens exactly one PDF device and closes it", {
  f <- withr::local_tempfile(fileext = ".pdf")
  before <- length(grDevices::dev.list())
  export_tfl(list(tfl_table(tbl_long), tfl_table(tbl_short), make_fig()), f)
  expect_equal(length(grDevices::dev.list()), before)
})

test_that("preview of a mixed list renders without writing a file", {
  f <- withr::local_tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit(grDevices::dev.off())
  expect_no_error(export_tfl(list(tfl_table(tbl_short), make_fig()), preview = TRUE))
})

# --- One PDF per element --------------------------------------------------------

test_that("one path per element writes one PDF each, in order, and returns the named normalized paths", {
  dir <- normalizePath(withr::local_tempdir())
  files <- file.path(dir, c("a.pdf", "b.pdf", "c.pdf"))
  ret <- export_tfl(
    list(
      a = list(list(content = tfl_table(tbl_long), caption = "A table"), list(content = make_fig(), caption = "A figure")),
      b = tfl_table(tbl_short),
      c = make_fig()
    ),
    files
  )
  expect_equal(ret, c(a = normalizePath(files[[1]]), b = normalizePath(files[[2]]), c = normalizePath(files[[3]])))
  expect_true(all(file.exists(files)))
  f_long <- withr::local_tempfile(fileext = ".pdf")
  export_tfl(tfl_table(tbl_long), f_long)
  expect_equal(unname(vapply(files, count_pdf_pages, numeric(1))), c(count_pdf_pages(f_long) + 1, 1, 1))
})

test_that("the per-file return value has no names when x has none, and equals the combined contract for one path", {
  dir <- normalizePath(withr::local_tempdir())
  files <- file.path(dir, c("a.pdf", "b.pdf"))
  ret <- export_tfl(list(tfl_table(tbl_short), make_fig()), files)
  expect_null(names(ret))
  expect_equal(ret, normalizePath(files))
  one <- export_tfl(list(tfl_table(tbl_short)), file.path(dir, "one.pdf"))
  expect_equal(one, normalizePath(file.path(dir, "one.pdf")))
  expect_null(names(one))
})

test_that("each element's page numbering restarts in its own file", {
  # Each element is exported by its own export_tfl() call, so its pagelist
  # (and `{n}`) is its own; check that against the combined count.
  pages_a <- combined_pages(list(list(content = tfl_table(tbl_long), caption = "A")))
  pages_b <- combined_pages(list(tfl_table(tbl_short)))
  expect_equal(page_args(pages_b, 1)$footer_right, "Page 1 of 1")
  expect_equal(page_args(pages_a, length(pages_a))$footer_right, sprintf("Page %d of %d", length(pages_a), length(pages_a)))
})

test_that("missing directories are created", {
  dir <- file.path(withr::local_tempdir(), "output", "tfl")
  files <- file.path(dir, c("a.pdf", "sub", "b.pdf"))[c(1, 3)]
  files <- c(file.path(dir, "a.pdf"), file.path(dir, "deeper", "b.pdf"))
  export_tfl(list(tfl_table(tbl_short), make_fig()), files)
  expect_true(all(file.exists(files)))
})

test_that("a path vector must match x: length, uniqueness, extension, preview, and list type", {
  dir <- withr::local_tempdir()
  x <- list(tfl_table(tbl_short), make_fig(), make_fig())
  expect_error(
    export_tfl(x, file.path(dir, c("a.pdf", "b.pdf"))),
    "`file` has 2 paths but `x` has 3 elements"
  )
  expect_error(
    export_tfl(x[1:2], file.path(dir, c("a.pdf", "a.pdf"))),
    "duplicate paths"
  )
  expect_error(
    export_tfl(x[1:2], file.path(dir, c("a.pdf", "./a.pdf"))),
    "duplicate paths"
  )
  expect_error(
    export_tfl(x[1:2], file.path(dir, c("a.pdf", "b.txt"))),
    "must be a character vector of paths ending in '.pdf'"
  )
  expect_error(
    export_tfl(x[1:2], c(file.path(dir, "a.pdf"), NA_character_)),
    "must be a character vector of paths ending in '.pdf'"
  )
  expect_error(
    export_tfl(x[1:2], file.path(dir, c("a.pdf", "b.pdf")), preview = TRUE),
    "`preview` cannot be used"
  )
  expect_error(
    export_tfl(tfl_table(tbl_short), file.path(dir, c("a.pdf", "b.pdf"))),
    "file must be a single character"
  )
  expect_error(
    export_tfl(make_fig(), file.path(dir, c("a.pdf", "b.pdf"))),
    "file must be a single character"
  )
  expect_equal(list.files(dir, all.files = TRUE, no.. = TRUE), character(0))
})

test_that("paths that differ only by case are duplicates where the file system ignores case", {
  skip_if_not(.is_case_insensitive_fs())
  dir <- withr::local_tempdir()
  expect_error(
    export_tfl(list(tfl_table(tbl_short), make_fig()), file.path(dir, c("a.pdf", "A.pdf"))),
    "duplicate paths"
  )
})

test_that("an empty list as an element is an error, not a PDF without pages", {
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("a.pdf", "b.pdf"))
  expect_error(
    export_tfl(list(a = tfl_table(tbl_short), b = list()), files),
    class = "writetfl_error_export_failed"
  )
  expect_true(file.exists(files[[1]]))
  expect_false(file.exists(files[[2]]))
})

test_that("one failing element does not stop the others, leaves no file or temp file, and is named in one error", {
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
  expect_match(msg, "Element bad ")
  expect_match(msg, "Element bad2 ")
  expect_false(grepl("Element ok", msg))
  expect_match(msg, "exceeds available content width")
  expect_true(file.exists(files[[1]]))
  expect_true(file.exists(files[[3]]))
  expect_false(file.exists(files[[2]]))
  expect_false(file.exists(files[[4]]))
  expect_setequal(list.files(dir, all.files = TRUE, no.. = TRUE), basename(files[c(1, 3)]))
  expect_equal(count_pdf_pages(files[[1]]), 1L)
})

test_that("a failing element leaves an existing file at its path untouched", {
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("keep.pdf", "other.pdf"))
  writeLines("previous content", files[[1]])
  expect_error(
    export_tfl(list(tfl_table(data.frame(a = strrep("x", 400))), tfl_table(tbl_short)), files),
    class = "writetfl_error_export_failed"
  )
  expect_equal(readLines(files[[1]]), "previous content")
  expect_true(file.exists(files[[2]]))
})

test_that("an element that has no name is identified by its position in the error", {
  dir <- withr::local_tempdir()
  err <- tryCatch(
    export_tfl(
      list(tfl_table(tbl_short), tfl_table(data.frame(a = strrep("x", 400)))),
      file.path(dir, c("a.pdf", "b.pdf"))
    ),
    error = function(e) e
  )
  expect_match(conditionMessage(err), "Element 2 ")
})

# --- workers ----------------------------------------------------------------------

test_that("workers is an error with a single path, and must be NULL, a whole number, or a cluster", {
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
  expect_equal(list.files(dir, all.files = TRUE, no.. = TRUE), character(0))
})

test_that("workers = 1 is sequential", {
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("a.pdf", "b.pdf"))
  expect_equal(
    export_tfl(list(tfl_table(tbl_short), make_fig()), files, workers = 1),
    normalizePath(files)
  )
  expect_true(all(file.exists(files)))
})

# Workers load the installed package, so a devtools::load_all() session cannot
# exercise the parallel path.
skip_if_dev_loaded <- function() {
  testthat::skip_if(
    exists(".__DEVTOOLS__", envir = asNamespace("writetfl")),
    "workers load the installed writetfl, not the devtools::load_all() copy"
  )
  testthat::skip_on_cran()
}

test_that("workers = 2 writes the same files as sequential, and stops the cluster it made", {
  skip_if_dev_loaded()
  x <- list(
    a = list(list(content = tfl_table(tbl_long), caption = "Long"), make_fig()),
    b = tfl_table(tbl_short),
    c = make_fig(),
    d = list(content = tfl_table(tbl_long), caption = "Again")
  )
  dir_seq <- withr::local_tempdir()
  dir_par <- withr::local_tempdir()
  files_seq <- file.path(dir_seq, paste0(names(x), ".pdf"))
  files_par <- file.path(dir_par, paste0(names(x), ".pdf"))
  ret_seq <- export_tfl(x, files_seq)
  connections_before <- nrow(showConnections())
  ret_par <- export_tfl(x, files_par, workers = 2)
  expect_equal(nrow(showConnections()), connections_before)
  expect_equal(names(ret_par), names(x))
  expect_equal(unname(ret_par), normalizePath(files_par))
  expect_equal(
    unname(vapply(ret_par, count_pdf_pages, numeric(1))),
    unname(vapply(ret_seq, count_pdf_pages, numeric(1)))
  )
  expect_setequal(list.files(dir_par, all.files = TRUE, no.. = TRUE), basename(files_par))
})

test_that("a cluster that is passed in is used and left running", {
  skip_if_dev_loaded()
  cl <- parallel::makeCluster(2)
  on.exit(parallel::stopCluster(cl))
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("a.pdf", "b.pdf", "c.pdf"))
  export_tfl(list(tfl_table(tbl_short), make_fig(), tfl_table(tbl_long)), files, workers = cl)
  expect_true(all(file.exists(files)))
  expect_equal(unlist(parallel::clusterEvalQ(cl, 1 + 1)), c(2, 2))
})

test_that("workers collects every failure and stops its cluster", {
  skip_if_dev_loaded()
  dir <- withr::local_tempdir()
  files <- file.path(dir, c("ok.pdf", "bad.pdf"))
  connections_before <- nrow(showConnections())
  err <- tryCatch(
    export_tfl(
      list(ok = tfl_table(tbl_short), bad = tfl_table(data.frame(a = strrep("x", 400)))),
      files, workers = 2
    ),
    error = function(e) e
  )
  expect_s3_class(err, "writetfl_error_export_failed")
  expect_match(conditionMessage(err), "Element bad ")
  expect_equal(nrow(showConnections()), connections_before)
  expect_equal(list.files(dir, all.files = TRUE, no.. = TRUE), "ok.pdf")
})

test_that("an output path is normalized through its directory, so '.' and '..' cannot hide a duplicate", {
  dir <- normalizePath(withr::local_tempdir())
  dir.create(file.path(dir, "sub"))
  expected <- normalizePath(file.path(dir, "a.pdf"), mustWork = FALSE)
  expect_equal(.normalize_output_path(file.path(dir, "a.pdf")), expected)
  expect_equal(.normalize_output_path(file.path(dir, ".", "a.pdf")), expected)
  expect_equal(.normalize_output_path(file.path(dir, "sub", "..", "a.pdf")), expected)
  # a file that does not exist yet and a root directory
  expect_equal(
    .normalize_output_path(file.path(dir, "not-yet.pdf")),
    normalizePath(file.path(dir, "not-yet.pdf"), mustWork = FALSE)
  )
  root <- normalizePath(.Platform$file.sep)
  expect_equal(.normalize_output_path(paste0(root, "a.pdf")), normalizePath(paste0(root, "a.pdf"), mustWork = FALSE))
  expect_false(grepl("//", .normalize_output_path(paste0(root, "a.pdf")), fixed = TRUE))
  expect_equal(
    export_tfl(list(tfl_table(tbl_short)), file.path(dir, ".", "viadot.pdf")),
    normalizePath(file.path(dir, "viadot.pdf"))
  )
})
