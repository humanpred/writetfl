# table_rows.R — Row height measurement and group-aware row pagination
#
# Functions:
#   measure_row_heights_tbl()  — memoised per-row height measurement
#   paginate_rows()            — split rows into pages respecting group boundaries

# ---------------------------------------------------------------------------
# measure_row_heights_tbl() — memoised row height measurement
# ---------------------------------------------------------------------------

#' Measure the rendered height of each data row in inches
#'
#' Must be called while a viewport is active.
#' Uses a memoised string-height function to avoid re-measuring repeated values.
#'
#' @return Numeric vector of row heights in inches (length = nrow(data)).
#' @keywords internal
measure_row_heights_tbl <- function(data, resolved_cols, gp_tbl, cell_padding,
                                    na_string, line_height, max_measure_rows) {
  n_rows   <- nrow(data)
  v_pad_in <- grid::convertHeight(cell_padding[["top"]],    "inches", valueOnly = TRUE) +
              grid::convertHeight(cell_padding[["bottom"]], "inches", valueOnly = TRUE)
  h_lft_in <- grid::convertWidth(cell_padding[["left"]],  "inches", valueOnly = TRUE)
  h_rgt_in <- grid::convertWidth(cell_padding[["right"]], "inches", valueOnly = TRUE)

  # Memoised height function: (string, gp_key) -> height_in
  memo <- new.env(hash = TRUE, parent = emptyenv())
  .memo_str_height <- function(s, gp_key, gp) {
    key <- paste0(gp_key, "\x01", s)
    if (!exists(key, envir = memo, inherits = FALSE)) {
      grob <- grid::textGrob(s, gp = gp)
      h    <- grid::convertHeight(grid::grobHeight(grob), "inches", valueOnly = TRUE)
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

  # Measure sampled rows
  sampled_heights <- vapply(sample_rows, function(i) {
    max(vapply(resolved_cols, function(cs) {
      cell_str <- .fmt_cell(data[[cs$col]][i], na_string)
      base_gp  <- .resolve_table_cell_gp(gp_tbl, cs$is_group_col)
      cell_gp  <- .gp_with_lineheight(base_gp, line_height)
      gp_key   <- paste0(if (cs$is_group_col) "group_col" else "data_row",
                         "_lh", line_height)
      # For wrap-eligible columns, wrap the text to the column width first
      display_str <- if (cs$wrap && !is.null(cs$width_in)) {
        avail_w <- cs$width_in - h_lft_in - h_rgt_in
        .wrap_text(cell_str, avail_w, cell_gp)
      } else {
        cell_str
      }
      # Count lines for conservative estimate
      nlines   <- max(1L, length(strsplit(display_str, "\n", fixed = TRUE)[[1L]]))
      h_grob   <- .memo_str_height(display_str, gp_key, cell_gp)
      h_line   <- nlines * grid::convertHeight(
                    grid::stringHeight("M"), "inches", valueOnly = TRUE)
      max(h_grob, h_line)
    }, numeric(1L))) + v_pad_in
  }, numeric(1L))

  max_sampled <- max(sampled_heights)

  # Build full height vector
  heights <- rep(max_sampled, n_rows)
  heights[sample_rows] <- sampled_heights
  heights
}

# ---------------------------------------------------------------------------
# paginate_rows() — group-aware row pagination
# ---------------------------------------------------------------------------

#' Split rows into pages, respecting group boundaries
#'
#' @param data Data frame.
#' @param row_heights_in Numeric vector of row heights in inches.
#' @param cont_row_h Height of a continuation-marker row in inches.
#' @param header_row_h Height of the column header row (0 if suppressed).
#' @param content_height_in Available content height per page.
#' @param group_vars Character vector of group column names.
#' @param row_cont_msg Text for continuation-marker rows.
#' @param group_rule Logical — are group rules drawn?
#' @return A list of row-page specs (see internal structure below).
#' @keywords internal
paginate_rows <- function(data, row_heights_in, cont_row_h, header_row_h,
                          content_height_in, group_vars, row_cont_msg,
                          group_rule) {
  n_rows  <- nrow(data)
  n_grp   <- length(group_vars)

  # Identify group boundaries: rows that start a new group
  group_starts <- .compute_group_starts(data, group_vars)

  pages      <- list()
  cur_rows   <- integer(0L)
  cur_h      <- header_row_h
  # Rule heights: rules are drawn within existing row boundaries, 0 extra height
  # (they render at the row boundary, not consuming additional space)

  flush_page <- function(rows, is_cont_top, is_cont_bottom) {
    pages[[length(pages) + 1L]] <<- list(
      rows           = rows,
      is_cont_top    = is_cont_top,
      is_cont_bottom = is_cont_bottom,
      group_starts   = intersect(group_starts, rows)
    )
  }

  i <- 1L
  is_cont_top <- FALSE  # does this page start with a (continued) row?

  while (i <= n_rows) {
    rh <- row_heights_in[[i]]

    # Would this row fit?
    extra_h <- rh
    if (is_cont_top) extra_h <- extra_h  # cont row already counted below

    needs_group_rule <- group_rule && i %in% group_starts && length(cur_rows) > 0L
    # Group rule uses no additional height (drawn at boundary)

    # Does adding this row overflow?
    if (cur_h + extra_h + cont_row_h > content_height_in + 1e-6 && length(cur_rows) > 0L) {

      # Warn whenever a group is split across pages (row i and the last row
      # on the current page belong to the same group)
      if (length(group_vars) > 0L && length(cur_rows) > 0L) {
        last_in_page <- cur_rows[length(cur_rows)]
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

      flush_page(cur_rows, is_cont_top, is_cont_bottom = TRUE)

      # Re-init next page with cont_top marker
      cur_rows     <- integer(0L)
      cur_h        <- header_row_h + cont_row_h  # top cont row
      is_cont_top  <- TRUE

      next  # restart loop iteration to re-add row i
    }

    cur_rows <- c(cur_rows, i)
    cur_h    <- cur_h + rh
    i        <- i + 1L
  }

  if (length(cur_rows) > 0L) {
    flush_page(cur_rows, is_cont_top, is_cont_bottom = FALSE)
  }

  pages
}
