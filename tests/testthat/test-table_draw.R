# test-table_draw.R — Tests for R/table_draw.R

library(dplyr, warn.conflicts = FALSE)

# drawDetails — uncached height fallback (lines 112-141) ----------------------
#
# build_table_grob() accepts row_heights_in = NULL and cont_row_h_in = NULL.
# When the grob is drawn, drawDetails falls back to recomputing those heights
# on the fly.  The test exercises both fallback branches and, via a wrap-
# eligible column, also the .wrap_text branch inside the row-height loop.

test_that("drawDetails recomputes cont_row_h and row_h_vec when not cached", {
  df <- data.frame(
    a = rep(paste(rep("word", 10), collapse = " "), 3),
    b = 1:3,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(
    df,
    cols = list(tfl_colspec("a", width = grid::unit(1.5, "inches"), wrap = TRUE))
  )

  # compute_col_widths populates width_in on each resolved col (required for draw)
  cw <- compute_col_widths(
    resolve_col_specs(tbl), tbl$data,
    content_width_in = 9,
    tbl, pg_width = 11, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  resolved <- cw$resolved_cols

  row_page <- list(
    rows           = 1:3,
    is_cont_top    = TRUE,   # forces the uncached cont_row_h branch
    is_cont_bottom = FALSE,
    group_starts   = integer(0L)
  )

  grob <- writetfl:::build_table_grob(
    row_page       = row_page,
    col_group_idx  = seq_along(resolved),
    n_group_cols   = 0L,
    resolved_cols  = resolved,
    tbl            = tbl,
    row_heights_in = NULL,   # force uncached row-height path
    cont_row_h_in  = NULL    # force uncached cont-row-height path
  )

  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) }, add = TRUE)

  vp <- grid::viewport(width  = grid::unit(9, "inches"),
                       height = grid::unit(7, "inches"))
  grid::pushViewport(vp)
  expect_no_error(grid::grid.draw(grob))
  grid::popViewport()
})

# drawDetails — .wrap_text in per-cell draw loop (line 231) -------------------

test_that("drawDetails calls .wrap_text for wrap-eligible columns during draw", {
  df <- data.frame(
    a = rep(paste(rep("long word", 10), collapse = " "), 3),
    b = 1:3,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(
    df,
    cols = list(tfl_colspec("a", width = grid::unit(1.5, "inches"), wrap = TRUE))
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
})

# drawDetails — column continuation side labels (rotated text) ----------------
#
# When is_first_col_page = FALSE or is_last_col_page = FALSE, drawDetails draws
# rotated text labels beside the table.  Exercises both branches.

test_that("drawDetails renders rotated col_cont_msg without error", {
  df <- as.data.frame(matrix(seq_len(20), nrow = 4,
                              dimnames = list(NULL, paste0("c", 1:5))))
  tbl <- tfl_table(df,
                   col_widths      = stats::setNames(
                     rep(list(grid::unit(3, "inches")), 5), paste0("c", 1:5)),
                   col_cont_msg    = "Columns continue",
                   allow_col_split = TRUE)

  pages <- writetfl:::tfl_table_to_pagelist(
    tbl, pg_width = 11, pg_height = 8.5, dots = list()
  )
  # There must be more than one column page for flags to vary
  expect_gt(length(pages), 1L)

  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  on.exit({ grDevices::dev.off(); unlink(f) }, add = TRUE)

  vp <- grid::viewport(width  = grid::unit(10, "inches"),
                       height = grid::unit(7.5, "inches"))
  grid::pushViewport(vp)

  # Draw all pages; exercises is_last_col_page = FALSE (right label)
  # and is_first_col_page = FALSE (left label)
  for (pg in pages) {
    expect_no_error(grid::grid.draw(pg$content))
  }

  grid::popViewport()
})

# .draw_cont_row() — first_data fallback (line 308) ---------------------------
#
# When ALL displayed columns are group columns (n_group_cols >= n_disp_cols),
# first_data falls back to 1.  This happens when the table has only one column
# and that column is the group variable.

test_that(".draw_cont_row falls back first_data to 1 when all cols are group cols", {
  df  <- data.frame(grp = rep(c("A", "B", "C", "D", "E"), 4),
                    stringsAsFactors = FALSE)
  tbl <- dplyr::group_by(df, grp) |> tfl_table()

  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  # Tiny page forces row pagination and thus continuation rows
  expect_no_error(
    export_tfl(tbl, file = f,
               pg_height          = 3,
               margins            = grid::unit(c(0.25, 0.25, 0.25, 0.25), "inches"),
               min_content_height = grid::unit(0.5, "inches"))
  )
})
