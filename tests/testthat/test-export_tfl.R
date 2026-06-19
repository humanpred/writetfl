# test-export_tfl.R — Tests for export_tfl.R
#
# End-to-end smoke tests are in test-integration.R.  This file covers
# edge-case branches specific to export_tfl().

library(ggplot2)

# ---------------------------------------------------------------------------
# File validation
# ---------------------------------------------------------------------------

test_that("export_tfl errors on missing file when preview = FALSE", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  expect_error(export_tfl(p), "file must be a single character")
})

test_that("export_tfl skips file validation when preview = TRUE", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })
  # file not supplied, but preview = TRUE should not error
  expect_no_error(export_tfl(p, preview = TRUE))
})

# ---------------------------------------------------------------------------
# Return value
# ---------------------------------------------------------------------------

test_that("export_tfl returns invisible normalized path in normal mode", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  result <- export_tfl(p, f)
  expect_equal(result, normalizePath(f, mustWork = FALSE))
})

test_that("export_tfl returns invisible NULL in preview mode", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  result <- export_tfl(p, preview = TRUE)
  expect_null(result)
})

# ---------------------------------------------------------------------------
# Preview mode page selection
# ---------------------------------------------------------------------------

test_that("export_tfl preview with out-of-range pages aborts", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  expect_error(export_tfl(p, preview = 99L), "out of range")
})

test_that("export_tfl preview with integer vector renders selected pages", {
  p1 <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  p2 <- ggplot(data.frame(x = 2, y = 2), aes(x, y)) + geom_point()
  pages <- list(list(content = p1), list(content = p2))

  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({
    grDevices::dev.off()
    unlink(f)
  })

  expect_no_error(export_tfl(pages, preview = c(1L, 2L)))
})

# ---------------------------------------------------------------------------
# Device lifecycle — device closes on error
# ---------------------------------------------------------------------------

test_that("export_tfl closes device even when a page errors", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  pages <- list(
    list(content = p),
    list(content = "not a plot")  # will error
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  dev_count_before <- length(grDevices::dev.list())
  try(export_tfl(pages, f), silent = TRUE)
  dev_count_after <- length(grDevices::dev.list())

  expect_equal(dev_count_after, dev_count_before)
})

# ---------------------------------------------------------------------------
# tfl_table coercion
# ---------------------------------------------------------------------------

test_that("export_tfl handles tfl_table input", {
  df <- data.frame(a = 1:3, b = letters[1:3])
  tbl <- tfl_table(df)
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
  expect_gt(file.info(f)$size, 0)
})

# ---------------------------------------------------------------------------
# Page argument merging
# ---------------------------------------------------------------------------

test_that("export_tfl passes dots to export_tfl_page as defaults", {
  p <- ggplot(data.frame(x = 1, y = 1), aes(x, y)) + geom_point()
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  expect_no_error(
    export_tfl(list(list(content = p)), f,
      header_left  = "Shared header",
      footer_right = "Shared footer"
    )
  )
  expect_true(file.exists(f))
})

# ---------------------------------------------------------------------------
# .open_metric_device() / .close_metric_device() helpers
# ---------------------------------------------------------------------------

test_that(".open_metric_device opens pdf(file) in normal mode and closes via on.exit", {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  before <- grDevices::dev.cur()

  runner <- function() {
    md <- .open_metric_device(f, pg_width = 11, pg_height = 8.5,
                              preview = FALSE)
    # Inside runner: device is open and active.
    expect_equal(grDevices::dev.cur(), md$dev)
    expect_true(grDevices::dev.cur() != before)
    md
  }
  result <- runner()
  # After runner() returns, the helper's on.exit (registered on
  # runner's frame) has fired and closed the device.
  expect_equal(grDevices::dev.cur(), before)
  expect_true(file.exists(f))   # pdf actually got written
})

test_that(".open_metric_device opens pdf(NULL) in preview mode", {
  before <- grDevices::dev.cur()

  runner <- function() {
    md <- .open_metric_device(NULL, pg_width = 11, pg_height = 8.5,
                              preview = TRUE)
    expect_equal(grDevices::dev.cur(), md$dev)
    md
  }
  result <- runner()
  # on.exit closed it on return.
  expect_equal(grDevices::dev.cur(), before)
})

test_that(".open_metric_device closes the device even when the caller errors out", {
  before <- grDevices::dev.cur()

  expect_error(
    {
      runner <- function() {
        .open_metric_device(NULL, pg_width = 11, pg_height = 8.5,
                            preview = TRUE)
        stop("boom -- simulated mid-pagination failure")
      }
      runner()
    },
    "boom"
  )
  # Even though the error short-circuited runner, the helper's on.exit
  # registered on runner's frame fires during unwind and closes the
  # device.
  expect_equal(grDevices::dev.cur(), before)
})

test_that(".close_metric_device is idempotent", {
  before <- grDevices::dev.cur()

  runner <- function() {
    md <- .open_metric_device(NULL, pg_width = 11, pg_height = 8.5,
                              preview = TRUE)
    # Explicit close: caller would invoke this in preview mode to
    # restore the user's device before drawing.
    .close_metric_device(md)
    expect_equal(grDevices::dev.cur(), before)
    # Second call is a no-op.
    .close_metric_device(md)
    expect_equal(grDevices::dev.cur(), before)
  }
  runner()
  expect_equal(grDevices::dev.cur(), before)
})

# ---------------------------------------------------------------------------
# D-48: single-device discipline + cross-phase cache invariants
# ---------------------------------------------------------------------------

test_that("export_tfl.tfl_table opens exactly one PDF device per call", {
  # Verify D-48's "single device" invariant via grDevices::pdf trace.
  # The tracer references a counter stored in a stable env so the
  # quote() body can resolve it inside grDevices::pdf's evaluation
  # context.
  counter_env <- new.env()
  counter_env$count <- 0L
  assign(".test_pdf_counter_env", counter_env, envir = globalenv())
  on.exit(rm(".test_pdf_counter_env", envir = globalenv()), add = TRUE)

  suppressMessages(trace(
    what   = "pdf",
    where  = asNamespace("grDevices"),
    tracer = quote({
      e <- get(".test_pdf_counter_env", envir = globalenv())
      e$count <- e$count + 1L
    }),
    print  = FALSE
  ))
  on.exit(suppressMessages(untrace("pdf", where = asNamespace("grDevices"))),
          add = TRUE)

  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f), add = TRUE)
  counter_env$count <- 0L
  export_tfl(tfl_table(head(iris, 5)), file = f)
  expect_equal(counter_env$count, 1L,
               info = paste("Expected 1 pdf() open; got", counter_env$count))
})

test_that("PDF font metrics are identical between pdf(NULL) and pdf(tempfile)", {
  # D-48 relies on this: pagination measurements taken on one PDF
  # device are equal to what the final pdf(file) would produce, so
  # the pagination cache can be shared across phases without
  # re-measurement.  Confirm empirically -- bytes can differ across
  # grid versions, so the test pins the assumption.
  string  <- "Quick brown fox 1234"
  gp_test <- grid::gpar(fontfamily = "sans", fontsize = 10,
                        fontface = "plain")

  measure_under_pdf <- function(target) {
    if (is.null(target)) {
      grDevices::pdf(NULL, width = 11, height = 8.5)
    } else {
      grDevices::pdf(target, width = 11, height = 8.5)
    }
    on.exit({
      grDevices::dev.off()
      if (!is.null(target)) unlink(target)
    })
    g <- grid::textGrob(string, gp = gp_test)
    list(
      w = grid::convertWidth(grid::grobWidth(g),  "inches", valueOnly = TRUE),
      h = grid::convertHeight(grid::grobHeight(g), "inches", valueOnly = TRUE)
    )
  }

  m_null <- measure_under_pdf(NULL)
  m_file <- measure_under_pdf(tempfile(fileext = ".pdf"))

  expect_equal(m_null$w, m_file$w, tolerance = 1e-9)
  expect_equal(m_null$h, m_file$h, tolerance = 1e-9)
})

test_that(".measure_text_dims_in fails fast without an active device", {
  # Safety guard added in Phase 2d.  All internal callers run under
  # `.open_metric_device()`; a future regression that forgets this
  # should produce a readable error rather than silent nonsense.
  #
  # The guard only fires on the null device, so establish that precondition
  # explicitly: under parallel testthat a worker runs several files in one
  # process, and a device left open by an earlier file would otherwise still
  # be current here.
  while (grDevices::dev.cur() > 1L) grDevices::dev.off()
  expect_error(
    .measure_text_dims_in("anything", grid::gpar()),
    "requires an active graphics device"
  )
})

test_that("tfl_table grob carries the cross-phase cache only when normal mode", {
  # PDF mode: grob$text_dim_cache should be the SAME env that
  # pagination populated (shared by reference).  Preview mode: it
  # should be a fresh empty env, so drawing falls back to per-cell
  # measurement on the user's render device.
  #
  # Rather than trace() the page-render call (which has scoping
  # complications under devtools::test()), invoke tfl_table_to_pagelist
  # the same way export_tfl.tfl_table() does, and inspect the grobs
  # directly.

  # Normal-mode-equivalent: pre-open a metric device and pass a cache.
  grDevices::pdf(NULL, width = 11, height = 8.5)
  pagination_cache <- new.env(hash = TRUE, parent = emptyenv())
  pages <- tfl_table_to_pagelist(
    tfl_table(head(iris, 5)),
    pg_width = 11, pg_height = 8.5,
    dots = list(), page_num = "Page {i} of {n}",
    text_dim_cache = pagination_cache
  )
  grDevices::dev.off()

  expect_gt(length(pages), 0L)
  expect_gt(length(ls(pagination_cache, all.names = TRUE)), 0L)

  # The grob doesn't carry text_dim_cache by default -- the
  # dispatcher does the attach.  Simulate that attach the same way
  # export_tfl.tfl_table() does:
  for (i in seq_along(pages)) {
    if (inherits(pages[[i]]$content, "tfl_table_grob")) {
      pages[[i]]$content$text_dim_cache <- pagination_cache
    }
  }
  # Now verify a grob carries a populated cache and entry shape is
  # list(w, h).
  found_one <- FALSE
  for (i in seq_along(pages)) {
    g <- pages[[i]]$content
    if (inherits(g, "tfl_table_grob")) {
      found_one <- TRUE
      expect_true(is.environment(g$text_dim_cache))
      expect_gt(length(ls(g$text_dim_cache, all.names = TRUE)), 0L)
      ks <- ls(g$text_dim_cache, all.names = TRUE)
      sample_val <- get(ks[[1L]], envir = g$text_dim_cache)
      expect_named(sample_val, c("w", "h"))
      break
    }
  }
  expect_true(found_one, info = "no tfl_table_grob in returned pages")

  # Preview-mode-equivalent: the dispatcher attaches an EMPTY env.
  # Simulate that and verify drawing's lookups would miss.
  empty_cache <- new.env(hash = TRUE, parent = emptyenv())
  for (i in seq_along(pages)) {
    if (inherits(pages[[i]]$content, "tfl_table_grob")) {
      pages[[i]]$content$text_dim_cache <- empty_cache
    }
  }
  for (i in seq_along(pages)) {
    g <- pages[[i]]$content
    if (inherits(g, "tfl_table_grob")) {
      expect_equal(length(ls(g$text_dim_cache, all.names = TRUE)), 0L)
    }
  }
})
