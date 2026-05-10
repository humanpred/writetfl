# table_rows.R — Row height measurement and group-aware row pagination
#
# Functions:
#   measure_row_heights_tbl()    — per-cell height matrix
#   .compute_page_row_heights()  — resolve per-row heights with group spanning
#   paginate_rows()              — split rows into pages (span-aware)

# ---------------------------------------------------------------------------
# measure_row_heights_tbl() — per-cell height matrix
# ---------------------------------------------------------------------------

#' Measure the rendered height of each table cell in inches
#'
#' Must be called while a viewport is active.
#' Uses a memoised string-height function to avoid re-measuring repeated values.
#'
#' Returns a matrix of cell heights (rows = data rows, cols = resolved_cols).
#' Each entry is the rendered height of that cell in inches, **including the
#' top + bottom cell padding (`v_pad_in`)** so that the per-row height is
#' simply `max(cell_h_mat[i, ])` without further adjustment.
#'
#' @param max_measure_rows Maximum number of rows to measure individually.
#'   Non-sampled rows take the per-column max of the sampled rows (a
#'   conservative estimate that mirrors prior behaviour).
#' @return Numeric matrix `[nrow(data) × length(resolved_cols)]` of inches.
#' @keywords internal
measure_row_heights_tbl <- function(data, resolved_cols, gp_tbl, cell_padding,
                                    na_string, line_height, max_measure_rows,
                                    breaks = NULL, wrap_extra_pad_in = 0) {
  n_rows   <- nrow(data)
  n_cols   <- length(resolved_cols)
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  h_lft_in <- .width_in(cell_padding[["left"]])
  h_rgt_in <- .width_in(cell_padding[["right"]])

  # Memoised per-cell-text-height function: (string, gp_key) -> height_in
  memo <- new.env(hash = TRUE, parent = emptyenv())
  .memo_str_height <- function(s, gp_key, gp) {
    key <- paste0(gp_key, "\x01", s)
    if (!exists(key, envir = memo, inherits = FALSE)) {
      grob <- grid::textGrob(s, gp = gp)
      h    <- .height_in(grid::grobHeight(grob))
      assign(key, h, envir = memo)
    }
    get(key, envir = memo, inherits = FALSE)
  }

  # Limit rows sampled for height estimation
  sample_rows <- if (is.finite(max_measure_rows) && n_rows > max_measure_rows) {
    # Sample the rows with the longest total text (most likely to be tallest)
    row_chars <- vapply(seq_len(n_rows), function(i) {
      sum(vapply(resolved_cols, function(cs) {
        nchar(.fmt_cell(data[[cs$col]][i], na_string))
      }, integer(1L)))
    }, integer(1L))
    order(row_chars, decreasing = TRUE)[seq_len(max_measure_rows)]
  } else {
    seq_len(n_rows)
  }

  # Build the matrix.  Iterate column-major so we can resolve gpar once per
  # column rather than once per cell.
  cell_h_mat <- matrix(0, nrow = n_rows, ncol = n_cols)
  for (j in seq_len(n_cols)) {
    cs       <- resolved_cols[[j]]
    base_gp  <- .resolve_table_cell_gp(gp_tbl, cs$is_group_col)
    cell_gp  <- .gp_with_lineheight(base_gp, line_height)
    gp_key   <- paste0(if (cs$is_group_col) "group_col" else "data_row",
                       "_lh", line_height)
    avail_w  <- if (!is.null(cs$width_in)) cs$width_in - h_lft_in - h_rgt_in
                else NA_real_

    for (i in sample_rows) {
      cell_str <- .fmt_cell(data[[cs$col]][i], na_string)
      display_str <- if (isTRUE(cs$wrap) && !is.null(cs$width_in)) {
        if (is.null(breaks)) {
          .wrap_text(cell_str, avail_w, cell_gp)
        } else {
          .wrap_string(cell_str, avail_w, cell_gp, breaks)
        }
      } else {
        cell_str
      }
      nlines  <- max(1L, length(strsplit(display_str, "\n", fixed = TRUE)[[1L]]))
      h_grob  <- .memo_str_height(display_str, gp_key, cell_gp)
      h_line  <- nlines * .height_in(grid::stringHeight("M"))
      extra   <- if (nlines > 1L) wrap_extra_pad_in else 0
      cell_h_mat[i, j] <- max(h_grob, h_line) + v_pad_in + extra
    }
  }

  # For non-sampled rows, fill each column with the per-column max-of-sampled
  # so that conservative heights are preserved.
  if (length(sample_rows) < n_rows) {
    not_sampled <- setdiff(seq_len(n_rows), sample_rows)
    if (length(sample_rows) > 0L) {
      col_max <- apply(cell_h_mat[sample_rows, , drop = FALSE], 2L, max)
    } else {
      col_max <- rep(0, n_cols) # nocov
    }
    for (j in seq_len(n_cols)) {
      cell_h_mat[not_sampled, j] <- col_max[[j]]
    }
  }

  cell_h_mat
}

# ---------------------------------------------------------------------------
# .compute_page_row_heights() — resolve per-row heights for one page
# ---------------------------------------------------------------------------

# Compute the per-row heights for the rows on a single page.
#
# A single rule, dispatched on whether suppression is active:
#
#  * **`suppress_mat` is `NULL`** — suppression is off, so every group
#    cell renders on every row.  Row height is the per-row max over
#    every cell (group and non-group alike).
#
#  * **`suppress_mat` is non-NULL** — suppression is on.  Group columns
#    never inflate row heights.  Initialise row_h from non-group cells
#    only, then walk group_vars innermost-first and, for each span,
#    grow row_h[span_start] only if the label exceeds the cumulative
#    span height — which lets multi-line labels flow downward through
#    the blanked cells (HTML-`rowspan` behaviour) instead of inflating
#    just the labelled row.  Innermost-first so outer spans can borrow
#    space inner spans already pushed for.  First-row growth matches
#    the label's top-aligned drawing.
#
# @param cell_h_mat Full matrix of cell heights including v_pad (inches).
# @param page_rows  Integer vector of data-row indices visible on this page.
# @param resolved_cols List of resolved column specs (full list, not just page).
# @param group_vars Character vector of group column names.
# @param suppress_mat Logical matrix [length(page_rows) × length(group_vars)]
#   from .compute_cell_suppression(), or NULL when suppression is disabled.
# @return Numeric vector of length(page_rows), heights in inches.
#' @keywords internal
.compute_page_row_heights <- function(cell_h_mat, page_rows, resolved_cols,
                                      group_vars, suppress_mat) {
  n_pr <- length(page_rows)
  if (n_pr == 0L) return(numeric(0L))

  n_grp <- length(group_vars)

  col_names <- vapply(resolved_cols, function(cs) cs$col, character(1L))
  is_group  <- vapply(resolved_cols, function(cs) isTRUE(cs$is_group_col),
                      logical(1L))

  # Per-row max over non-group cells.  Falls back to the full-matrix max
  # if every column is somehow a group column (degenerate input).
  non_group_idx <- which(!is_group)
  ng_max <- if (length(non_group_idx) > 0L) {
    apply(cell_h_mat[page_rows, non_group_idx, drop = FALSE], 1L, max)
  } else {
    apply(cell_h_mat[page_rows, , drop = FALSE], 1L, max) # nocov
  }
  row_h <- as.numeric(ng_max)

  if (n_grp == 0L) return(row_h)
  group_col_idx <- match(group_vars, col_names)

  if (is.null(suppress_mat)) {
    # No suppression: every group cell is rendered fully on its row, so
    # group cells contribute to the row max alongside non-group cells.
    for (g in seq_len(n_grp)) {
      j_mat <- group_col_idx[[g]]
      if (is.na(j_mat)) next   # safety; shouldn't happen
      row_h <- pmax(row_h, cell_h_mat[page_rows, j_mat])
    }
    return(row_h)
  }

  # Suppression on: group columns never inflate rows.  For each span the
  # label is amortised across the span and only grows the start row when
  # the deficit is positive (so a multi-line label flows downward into
  # the suppressed cells).  Innermost-first lets outer spans borrow
  # whatever growth inner spans already produced.
  for (g in rev(seq_len(n_grp))) {
    j_mat <- group_col_idx[[g]]
    if (is.na(j_mat)) next   # safety; shouldn't happen

    starts <- which(!suppress_mat[, g])
    if (length(starts) == 0L) next   # entire column suppressed (shouldn't happen)
    ends   <- c(starts[-1L] - 1L, n_pr)

    for (s_idx in seq_along(starts)) {
      ri_start <- starts[[s_idx]]
      ri_end   <- ends[[s_idx]]
      label_h  <- cell_h_mat[page_rows[[ri_start]], j_mat]
      avail    <- sum(row_h[ri_start:ri_end])
      if (label_h > avail + 1e-9) {
        row_h[[ri_start]] <- row_h[[ri_start]] + (label_h - avail)
      }
    }
  }
  row_h
}

# ---------------------------------------------------------------------------
# paginate_rows() — group-aware row pagination
# ---------------------------------------------------------------------------

#' Split rows into pages, respecting group boundaries
#'
#' Uses a per-page tentative recompute of `.compute_page_row_heights()` so that
#' span-aware row heights drive the page-fit decision.  Two non-obvious
#' properties of this scheme are preserved by the algorithm:
#'
#' * Adding a row to an existing group-span on the current page may leave the
#'   total page height unchanged (the span absorbs deficit that previously
#'   inflated earlier rows), so more rows can fit than a per-row scalar sum
#'   would predict.
#' * When only the first row of a multi-row group lands on the current page
#'   (group orphan), that row's span on the page is length 1 and the row is
#'   grown to fit the full label height.  `committed_rh` snapshots heights
#'   after each successful append, so the orphan-correct heights are what gets
#'   flushed to the page spec.
#'
#' @param data Data frame.
#' @param cell_h_mat Per-cell height matrix from `measure_row_heights_tbl()`.
#' @param resolved_cols Full list of resolved column specs (used to identify
#'   non-group columns).
#' @param group_vars Character vector of group column names.
#' @param cont_row_h Height of a continuation-marker row in inches.
#' @param header_row_h Height of the column header row (0 if suppressed).
#' @param content_height_in Available content height per page.
#' @param row_cont_msg Text for continuation-marker rows.
#' @param group_rule Logical — are group rules drawn?  (Reserved for future
#'   use; currently does not affect pagination because rules are 0-height.)
#' @param suppress_repeated_groups Logical, from `tbl$suppress_repeated_groups`.
#' @param overflow_action One of `"error"` (default) or `"warn"`. Controls how
#'   the row-overflow guard reports a single row whose committed height
#'   exceeds the available page content height (a row that wraps to taller
#'   than one page is almost always a sign of input that needs to change).
#'   The same knob downgrades column-overflow events; see [export_tfl_page()].
#' @return A list of row-page specs, each with `$rows`, `$is_cont_top`,
#'   `$is_cont_bottom`, `$group_starts`, and `$row_heights_in` (the committed
#'   per-row heights for that page in inches).
#' @keywords internal
paginate_rows <- function(data, cell_h_mat, resolved_cols, group_vars,
                          cont_row_h, header_row_h, content_height_in,
                          row_cont_msg, group_rule,
                          suppress_repeated_groups = TRUE,
                          overflow_action          = "error") {
  n_rows <- nrow(data)

  # Group boundaries in the *full* data — used for the page-spec $group_starts
  # field that the drawing code consults for group-rule placement.
  group_starts <- .compute_group_starts(data, group_vars)

  pages         <- list()
  cur_rows      <- integer(0L)
  committed_rh  <- numeric(0L)  # heights for cur_rows after last successful add
  is_cont_top   <- FALSE
  errors        <- character(0L)

  flush_page <- function(rows, row_heights_in, is_cont_top, is_cont_bottom) {
    pages[[length(pages) + 1L]] <<- list(
      rows           = rows,
      is_cont_top    = is_cont_top,
      is_cont_bottom = is_cont_bottom,
      group_starts   = intersect(group_starts, rows),
      row_heights_in = row_heights_in
    )
  }

  i <- 1L
  while (i <= n_rows) {
    candidate <- c(cur_rows, i)
    sup       <- if (suppress_repeated_groups && length(group_vars) > 0L) {
      .compute_cell_suppression(data, group_vars, candidate)
    } else NULL
    rh        <- .compute_page_row_heights(
      cell_h_mat, candidate, resolved_cols, group_vars, sup
    )
    total     <- header_row_h +
                 (if (is_cont_top) cont_row_h else 0) +
                 sum(rh) +
                 cont_row_h   # reserve bottom continuation marker

    if (total > content_height_in + 1e-6) {
      if (length(cur_rows) > 0L) {
        # Warn whenever a group is split across pages (row i and the last row
        # on the current page belong to the same group).
        if (length(group_vars) > 0L) {
          last_in_page <- cur_rows[[length(cur_rows)]]
          same_group   <- all(vapply(group_vars, function(gv) {
            identical(data[[gv]][last_in_page], data[[gv]][i])
          }, logical(1L)))
          if (same_group) {
            rlang::warn(sprintf(
              paste0("Row %d belongs to a group that spans more than one page. ",
                     "A '(continued)' marker will be added at the boundary."), i
            ))
          }
        }

        flush_page(cur_rows, committed_rh, is_cont_top, is_cont_bottom = TRUE)

        cur_rows     <- integer(0L)
        committed_rh <- numeric(0L)
        is_cont_top  <- TRUE
        next   # re-process row i on a fresh page
      } else {
        # Row i alone is being committed.  `total` is the conservative budget
        # including a *reserved* bottom continuation marker that may not be
        # drawn when this row turns out to be the last on the page.  Only
        # signal a true overflow when the row exceeds the page height even
        # without that reserve - then no amount of pagination can rescue it.
        min_required <- header_row_h +
                        (if (is_cont_top) cont_row_h else 0) +
                        sum(rh)
        if (min_required > content_height_in + 1e-6) {
          msg <- sprintf(
            paste0("Row %d of the table wraps to a height (%.3g in) that ",
                   "exceeds the available page content height (%.3g in). ",
                   "Reduce the cell content, increase the page height, widen ",
                   "the column, or set the column to wrap less aggressively."),
            i, sum(rh), content_height_in
          )
          errors <- .overflow_signal(msg, overflow_action, errors)
        }
        # Fall through to commit the row.
      }
    }

    cur_rows     <- candidate
    committed_rh <- rh
    i            <- i + 1L
  }

  if (length(cur_rows) > 0L) {
    flush_page(cur_rows, committed_rh, is_cont_top, is_cont_bottom = FALSE)
  }

  if (length(errors) > 0L) {
    rlang::abort(paste(errors, collapse = "\n"))
  }

  pages
}
