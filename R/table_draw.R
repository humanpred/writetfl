# table_draw.R — Table grob construction and drawDetails dispatch
#
# build_table_grob()       — assembles a "tfl_table_grob" gTree
# drawDetails.tfl_table_grob() — draws the table when rendered

# ---------------------------------------------------------------------------
# .compute_cell_suppression() — hierarchical group repeat suppression
# ---------------------------------------------------------------------------

# Returns a logical matrix [length(rows) x length(group_vars)].
# TRUE means the cell should be suppressed (show as blank).
# When an outer group column changes, all inner columns reset so their values
# are re-shown even if numerically equal to the previous row's value.
.compute_cell_suppression <- function(data, group_vars, rows) {
  n_rows <- length(rows)
  n_grp  <- length(group_vars)
  if (n_grp == 0L || n_rows == 0L) {
    return(matrix(FALSE, nrow = n_rows, ncol = n_grp,
                  dimnames = list(NULL, group_vars)))
  }
  suppress <- matrix(FALSE, nrow = n_rows, ncol = n_grp,
                     dimnames = list(NULL, group_vars))
  last_val <- rep(list(NULL), n_grp)

  for (ri in seq_len(n_rows)) {
    i      <- rows[[ri]]
    i_prev <- if (ri > 1L) rows[[ri - 1L]] else NULL
    for (j in seq_len(n_grp)) {
      raw_val <- data[[group_vars[[j]]]][[i]]
      if (!is.null(i_prev) && j > 1L) {
        for (k in seq_len(j - 1L)) {
          if (!identical(data[[group_vars[[k]]]][[i_prev]],
                         data[[group_vars[[k]]]][[i]])) {
            last_val[j] <- list(NULL)
            break
          }
        }
      }
      if (!is.null(last_val[[j]]) && identical(last_val[[j]], raw_val)) {
        suppress[ri, j] <- TRUE
      } else {
        last_val[[j]] <- raw_val
      }
    }
  }
  suppress
}

# ---------------------------------------------------------------------------
# build_table_grob() — assemble the grob
# ---------------------------------------------------------------------------

#' Build a grid grob for one page of a tfl_table
#'
#' @param row_page List from paginate_rows(): $rows, $is_cont_top,
#'   $is_cont_bottom, $group_starts.
#' @param col_group_idx Integer vector of column indices (1-based into
#'   resolved_cols) for this column group, including row-header columns first.
#' @param n_group_cols Number of row-header (group) columns.
#' @param resolved_cols Full list of resolved column specs (all columns).
#' @param tbl The tfl_table object.
#' @return A gTree of class "tfl_table_grob".
#' @keywords internal
build_table_grob <- function(row_page, col_group_idx, n_group_cols,
                             resolved_cols, tbl,
                             cell_heights_in_mat = NULL,
                             cont_row_h_in       = NULL,
                             is_first_col_page   = TRUE,
                             is_last_col_page    = TRUE) {
  # Subset to display columns for this page
  page_cols <- resolved_cols[col_group_idx]

  grid::gTree(
    row_page            = row_page,
    col_group_idx       = col_group_idx,
    n_group_cols        = n_group_cols,
    page_cols           = page_cols,
    resolved_cols       = resolved_cols,        # full list, for span recompute
    tbl                 = tbl,
    cell_heights_in_mat = cell_heights_in_mat,  # cached full matrix
    cont_row_h_in       = cont_row_h_in,        # cached from paginate phase
    is_first_col_page   = is_first_col_page,    # FALSE when prior col pages exist
    is_last_col_page    = is_last_col_page,     # FALSE when more col pages follow
    cl                  = "tfl_table_grob"
  )
}

# ---------------------------------------------------------------------------
# drawDetails.tfl_table_grob — called by grid when the grob is rendered
# ---------------------------------------------------------------------------

#' Draw method for tfl_table_grob
#'
#' Called automatically by the grid graphics system when a `tfl_table_grob`
#' is rendered. Not intended to be called directly.
#'
#' @param x A `tfl_table_grob` object.
#' @param recording Logical; passed by grid (not used directly).
#' @return Called for its side effect of drawing the table.
#' @importFrom grid drawDetails
#' @method drawDetails tfl_table_grob
#' @export
drawDetails.tfl_table_grob <- function(x, recording) {

  tbl         <- x$tbl
  page_cols   <- x$page_cols
  row_page    <- x$row_page
  n_group_cols <- x$n_group_cols
  n_disp_cols  <- length(page_cols)
  n_data_cols  <- n_disp_cols - n_group_cols

  # Get viewport dimensions
  vp_w <- .width_in(grid::unit(1, "npc"))
  vp_h <- .height_in(grid::unit(1, "npc"))

  # Cell padding in inches
  cp       <- tbl$cell_padding
  v_top_in <- .height_in(cp[["top"]])
  v_bot_in <- .height_in(cp[["bottom"]])
  h_lft_in <- .width_in(cp[["left"]])
  h_rgt_in <- .width_in(cp[["right"]])

  # Column x positions (in inches from left edge of viewport)
  col_widths_in <- vapply(page_cols, `[[`, numeric(1L), "width_in")
  col_x_left    <- c(0, cumsum(col_widths_in[-n_disp_cols]))
  col_x_right   <- cumsum(col_widths_in)
  x_offset    <- max(0, (vp_w - sum(col_widths_in)) / 2)
  col_x_left  <- col_x_left  + x_offset
  col_x_right <- col_x_right + x_offset

  data     <- tbl$data
  na_str   <- tbl$na_string
  gp_tbl   <- tbl$gp
  v_pad_in <- v_top_in + v_bot_in
  breaks   <- tbl$wrap_breaks %||% wrap_breaks_default()
  wrap_extra_pad_in <- if (!is.null(tbl$wrap_extra_padding)) {
    .height_in(tbl$wrap_extra_padding)
  } else 0

  # Use cached heights from the pagination phase (ensures layout consistency).
  # Fall back to re-measurement only when cache is absent.
  rows   <- row_page$rows
  n_rows <- length(rows)

  lh <- tbl$line_height %||% 1.05   # defensive fallback for old grob objects

  # Header row height (delegates to the same helper used during pagination so
  # any auto-wrapping of column labels is accounted for here too).
  header_row_h <- if (tbl$show_col_names) {
    .measure_header_row_height(page_cols, gp_tbl, cp, lh, breaks = breaks,
                               wrap_extra_pad_in = wrap_extra_pad_in)
  } else 0

  # Continuation row height — prefer cached value
  cont_row_h <- if (!is.null(x$cont_row_h_in)) {
    x$cont_row_h_in
  } else {
    cont_gp <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "continued"), lh)
    .cont_h <- function(msg) {
      grob <- grid::textGrob(msg, gp = cont_gp)
      h1   <- .height_in(grid::grobHeight(grob))
      h2   <- .height_in(grid::stringHeight("M"))
      max(h1, h2) + v_pad_in
    }
    max(vapply(tbl$row_cont_msg, .cont_h, numeric(1L)))
  }

  group_vars <- tbl$group_vars

  # Precompute the per-page suppression matrix.  Drives cell-content
  # blanking, span-aware row heights, span clipping for non-suppressed
  # group cells, and within-span row-rule suppression.
  suppress_mat <- if (isTRUE(tbl$suppress_repeated_groups) &&
                      length(group_vars) > 0L) {
    .compute_cell_suppression(data, group_vars, rows)
  } else NULL

  # Per-page row heights — prefer the heights that pagination committed; if
  # absent, recompute from the cached cell-height matrix using the same
  # algorithm pagination uses.  As a final fallback, build a per-page
  # matrix on the fly (covers grobs assembled outside the normal pipeline).
  row_h_vec <- if (!is.null(row_page$row_heights_in) &&
                   length(row_page$row_heights_in) == n_rows) {
    row_page$row_heights_in
  } else if (!is.null(x$cell_heights_in_mat) && !is.null(x$resolved_cols)) {
    .compute_page_row_heights(
      x$cell_heights_in_mat, rows, x$resolved_cols, group_vars, suppress_mat
    )
  } else {
    # Per-page fallback: build a small matrix for just the rows on this page
    # using page_cols, then apply the algorithm.
    fallback_mat <- matrix(0, nrow = n_rows, ncol = length(page_cols))
    for (j in seq_along(page_cols)) {
      cs   <- page_cols[[j]]
      gp_c <- .gp_with_lineheight(
        .resolve_table_cell_gp(gp_tbl, cs$is_group_col), lh
      )
      for (ri in seq_len(n_rows)) {
        s      <- .fmt_cell(data[[cs$col]][rows[[ri]]], na_str)
        disp_s <- if (isTRUE(cs$wrap) && !is.null(cs$width_in)) {
          .wrap_string(s, cs$width_in - h_lft_in - h_rgt_in, gp_c, breaks)
        } else s
        nlines <- max(1L, length(strsplit(disp_s, "\n", fixed = TRUE)[[1L]]))
        grob   <- grid::textGrob(disp_s, gp = gp_c)
        h1     <- .height_in(grid::grobHeight(grob))
        h2     <- nlines * .height_in(grid::stringHeight("M"))
        extra  <- if (nlines > 1L) wrap_extra_pad_in else 0
        fallback_mat[ri, j] <- max(h1, h2) + v_pad_in + extra
      }
    }
    .compute_page_row_heights(
      fallback_mat, seq_len(n_rows), page_cols, group_vars, suppress_mat
    )
  }

  # Group-rule metadata: outermost-changing-level size + level for each
  # group_start.  Drawing reads $levels to set the rule's left-edge column
  # (so unchanged outer columns aren't sliced through by the rule line).
  group_rule_info <- if (tbl$group_rule && length(group_vars) > 0L) {
    .compute_group_rule_info(data, group_vars)
  } else NULL

  # Precompute span ends per group column on this page so non-suppressed
  # group cells can be drawn with a clip viewport that covers the whole
  # span.  span_end_mat[ri, g] is the last row index in the same span as
  # ri for group column g.
  span_end_mat <- if (!is.null(suppress_mat)) {
    se <- matrix(NA_integer_, nrow = n_rows, ncol = length(group_vars))
    for (g in seq_along(group_vars)) {
      starts <- which(!suppress_mat[, g])
      if (length(starts) > 0L) {
        ends <- c(starts[-1L] - 1L, n_rows)
        se[starts, g] <- ends
      }
    }
    se
  } else NULL

  # --- Build row y-positions (top-to-bottom, in inches from top of vp) ---
  # In grid: y=0 is bottom, y=1 is top.
  # We track y_top_in = distance from TOP of viewport (increasing downward).

  y_cursor <- 0   # distance from top in inches

  # Draw column header row
  if (tbl$show_col_names) {
    # Header row background fill
    hdr_gp_full <- .resolve_table_gp(gp_tbl, "header_row")
    if (!is.null(hdr_gp_full$fill)) {
      x_l <- col_x_left[[1L]]          / vp_w
      x_r <- col_x_right[[n_disp_cols]] / vp_w
      y_mid <- 1 - (y_cursor + header_row_h / 2) / vp_h
      grid::grid.rect(
        x      = grid::unit((x_l + x_r) / 2, "npc"),
        y      = grid::unit(y_mid, "npc"),
        width  = grid::unit(x_r - x_l, "npc"),
        height = grid::unit(header_row_h / vp_h, "npc"),
        gp     = grid::gpar(fill = hdr_gp_full$fill, col = NA)
      )
    }
    .draw_header_row(page_cols, col_x_left, col_x_right, col_widths_in,
                     y_cursor, header_row_h, vp_w, vp_h,
                     h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh,
                     breaks = breaks)
    y_cursor <- y_cursor + header_row_h

    # Column header rule — spans table width only
    if (tbl$col_header_rule) {
      rule_gp    <- .resolve_table_gp(gp_tbl, "col_header_rule")
      y_rule_npc <- 1 - y_cursor / vp_h
      x_left_npc  <- col_x_left[[1L]]          / vp_w
      x_right_npc <- col_x_right[[n_disp_cols]] / vp_w
      grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                       y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                       gp = rule_gp)
    }
  }

  # Top continuation row
  if (row_page$is_cont_top) {
    .draw_cont_row(tbl$row_cont_msg[[1L]], n_group_cols, n_disp_cols,
                   col_x_left, col_x_right, y_cursor, cont_row_h,
                   vp_w, vp_h, h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh)
    y_cursor <- y_cursor + cont_row_h
  }

  # Group boundaries (track previous group key to detect changes)
  grp_starts <- row_page$group_starts

  # Data row background fill setup
  data_row_gp <- .resolve_table_gp(gp_tbl, "data_row")
  data_fill   <- data_row_gp$fill
  fill_by     <- tbl$fill_by %||% "row"
  group_fill_idx <- 1L

  # Per-column cell gpar.  Depends only on (gp_tbl, cs$is_group_col, lh), all
  # invariant across rows, so resolve once per column instead of once per cell.
  cell_gp_by_col <- lapply(page_cols, function(cs) {
    .gp_with_lineheight(.resolve_table_cell_gp(gp_tbl, cs$is_group_col), lh)
  })

  # Per-column clip-width memo: many cells in a column share identical text
  # (numeric formats like "5.1", category labels), and the clip-width
  # computation otherwise re-measures each one.  Cache scoped to this
  # drawDetails call and to one column, so a single (text -> width) key is
  # enough.
  clip_width_cache_by_col <- lapply(page_cols, function(cs) {
    new.env(hash = TRUE, parent = emptyenv())
  })

  # Pre-extract and pre-format each column's cell strings for the rows on
  # this page.  Replaces a per-cell `.fmt_cell(data[[cs$col]][i], na_str)`
  # with a single vectorised `.fmt_cell_vec()` per column.
  cell_strs_by_col <- lapply(page_cols, function(cs) {
    .fmt_cell_vec(data[[cs$col]][rows], na_str)
  })

  # Hoist row/group-rule gpars too -- they don't change between rows.  Only
  # resolved when the corresponding feature is active to avoid paying for
  # tables that never draw them.
  row_rule_gp   <- if (isTRUE(tbl$row_rule))
    .resolve_table_gp(gp_tbl, "row_rule")   else NULL
  group_rule_gp <- if (isTRUE(tbl$group_rule))
    .resolve_table_gp(gp_tbl, "group_rule") else NULL

  for (ri in seq_len(n_rows)) {
    i     <- rows[[ri]]
    row_h <- row_h_vec[[ri]]

    # Group rule before this row (if it starts a group and is not the first
    # visible row).  The rule starts at the column corresponding to the
    # outermost group_var level that actually changed at this transition,
    # so unchanged outer columns through which the label is flowing
    # aren't sliced.  Drawn at every transition.
    if (i %in% grp_starts && ri > 1L) group_fill_idx <- group_fill_idx + 1L
    if (tbl$group_rule && i %in% grp_starts && y_cursor > header_row_h + 1e-6 &&
        !is.null(group_rule_info)) {
      gk <- group_rule_info$levels[as.character(i)]
      if (!is.na(gk)) {
        rule_start_col <- min(as.integer(gk), n_disp_cols)
        y_rule_npc     <- 1 - y_cursor / vp_h
        x_left_npc     <- col_x_left[[rule_start_col]] / vp_w
        x_right_npc    <- col_x_right[[n_disp_cols]]   / vp_w
        grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                         y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                         gp = group_rule_gp)
      }
    }

    # Data row background fill
    if (!is.null(data_fill)) {
      fill_idx <- if (fill_by == "group") group_fill_idx else ri
      fill_col <- data_fill[(fill_idx - 1L) %% length(data_fill) + 1L]
      x_l <- col_x_left[[1L]]          / vp_w
      x_r <- col_x_right[[n_disp_cols]] / vp_w
      y_mid <- 1 - (y_cursor + row_h / 2) / vp_h
      grid::grid.rect(
        x      = grid::unit((x_l + x_r) / 2, "npc"),
        y      = grid::unit(y_mid, "npc"),
        width  = grid::unit(x_r - x_l, "npc"),
        height = grid::unit(row_h / vp_h, "npc"),
        gp     = grid::gpar(fill = fill_col, col = NA)
      )
    }

    # Draw data row
    for (j in seq_len(n_disp_cols)) {
      cs       <- page_cols[[j]]
      cell_str <- cell_strs_by_col[[j]][[ri]]

      # Group repeat suppression and span detection
      clip_h <- row_h
      if (!is.null(suppress_mat) && cs$is_group_col) {
        col_pos <- match(cs$col, group_vars, nomatch = 0L)
        if (col_pos > 0L) {
          if (suppress_mat[[ri, col_pos]]) {
            cell_str <- ""
          } else if (!is.null(span_end_mat)) {
            # Non-suppressed group cell: clip to the full span height so the
            # (possibly multi-line) label can flow into the suppressed rows
            # below it (HTML rowspan-style).
            ri_end <- span_end_mat[[ri, col_pos]]
            if (!is.na(ri_end) && ri_end > ri) {
              clip_h <- sum(row_h_vec[ri:ri_end])
            }
          }
        }
      }

      cell_gp <- cell_gp_by_col[[j]]

      # For wrap-eligible columns, apply word-wrapping before drawing using
      # the table's wrap_breaks spec (which may include keep_before chars
      # like "-").
      display_str <- if (isTRUE(cs$wrap) && nzchar(cell_str) &&
                         !is.null(cs$width_in)) {
        .wrap_string(cell_str, cs$width_in - h_lft_in - h_rgt_in,
                     cell_gp, breaks)
      } else {
        cell_str
      }

      .draw_cell_text(display_str, cs$align,
                      col_x_left[[j]], col_x_right[[j]],
                      y_cursor, clip_h, vp_w, vp_h,
                      h_lft_in, h_rgt_in, v_top_in,
                      cell_gp, cs$width_in,
                      width_cache = clip_width_cache_by_col[[j]])
    }

    y_cursor <- y_cursor + row_h

    # Row rule between data rows (not after last).  Suppress the rule if
    # the next row is part of a multi-row group span starting at or
    # before this row — drawing a horizontal line through a label that
    # flows downward would visually slice it.
    rule_inside_span <- !is.null(suppress_mat) && ri < n_rows &&
                        any(suppress_mat[ri + 1L, ])
    if (tbl$row_rule && ri < n_rows && !rule_inside_span) {
      y_rule_npc  <- 1 - y_cursor / vp_h
      x_left_npc  <- col_x_left[[1L]]          / vp_w
      x_right_npc <- col_x_right[[n_disp_cols]] / vp_w
      grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                       y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                       gp = row_rule_gp)
    }
  }

  # group_rule_after_last
  if (tbl$group_rule_after_last && n_rows > 0L) {
    rule_gp     <- .resolve_table_gp(gp_tbl, "group_rule")
    y_rule_npc  <- 1 - y_cursor / vp_h
    x_left_npc  <- col_x_left[[1L]]          / vp_w
    x_right_npc <- col_x_right[[n_disp_cols]] / vp_w
    grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                     y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                     gp = rule_gp)
  }

  # Bottom continuation row
  if (row_page$is_cont_bottom) {
    .draw_cont_row(tbl$row_cont_msg[[2L]], n_group_cols, n_disp_cols,
                   col_x_left, col_x_right, y_cursor, cont_row_h,
                   vp_w, vp_h, h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh)
    y_cursor <- y_cursor + cont_row_h
  }

  # Row header separator (vertical rule after last group col, data rows only)
  if (tbl$row_header_sep && n_group_cols > 0L) {
    sep_gp   <- .resolve_table_gp(gp_tbl, "row_header_sep")
    sep_x    <- col_x_right[[n_group_cols]] / vp_w  # npc x
    # Span from bottom of header row to bottom of last data/cont row
    y_top_npc    <- 1 - header_row_h / vp_h
    y_bottom_npc <- 1 - y_cursor / vp_h
    grid::grid.lines(x  = grid::unit(c(sep_x, sep_x), "npc"),
                     y  = grid::unit(c(y_bottom_npc, y_top_npc), "npc"),
                     gp = sep_gp)
  }

  # Column continuation side labels (rotated text)
  # Defensive fallback: treat absent flags as single-page (no labels drawn).
  is_first_col_page <- x$is_first_col_page %||% TRUE
  is_last_col_page  <- x$is_last_col_page  %||% TRUE

  if (!is.null(tbl$col_cont_msg) &&
      (!is_last_col_page || !is_first_col_page)) {
    col_cont_gp <- .gp_with_lineheight(
      .resolve_table_gp(gp_tbl, "continued"), lh
    )
    # Labels are centred at the viewport edge; margins provide the surrounding
    # space so the text remains fully visible.

    # Right side: clockwise 90° when columns continue on a subsequent page
    if (!is_last_col_page) {
      grid::grid.text(
        label = tbl$col_cont_msg[[2L]],
        x     = grid::unit(1, "npc"),
        y     = grid::unit(0.5, "npc"),
        rot   = -90,
        just  = "centre",
        gp    = col_cont_gp
      )
    }

    # Left side: counter-clockwise 90° when columns continue from a prior page
    if (!is_first_col_page) {
      grid::grid.text(
        label = tbl$col_cont_msg[[1L]],
        x     = grid::unit(0, "npc"),
        y     = grid::unit(0.5, "npc"),
        rot   = 90,
        just  = "centre",
        gp    = col_cont_gp
      )
    }
  }

  invisible(NULL)
}

# ---------------------------------------------------------------------------
# Drawing helpers
# ---------------------------------------------------------------------------

# Draw the column header row.
#
# When `breaks` is non-NULL and a column is wrap-eligible (`cs$wrap == TRUE`)
# with a resolved width, the label is auto-wrapped to fit the column before
# drawing, so a long header in a narrow column reflows onto multiple lines
# rather than overflowing.
.draw_header_row <- function(page_cols, col_x_left, col_x_right, col_widths_in,
                              y_top_in, row_h, vp_w, vp_h,
                              h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh,
                              breaks = NULL) {
  hdr_gp <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"), lh)
  for (j in seq_along(page_cols)) {
    cs    <- page_cols[[j]]
    label <- cs$label
    if (!is.null(breaks) && isTRUE(cs$wrap) && !is.null(cs$width_in)) {
      label <- .wrap_label_for_width(label, cs$width_in,
                                      h_lft_in + h_rgt_in, hdr_gp, breaks)
    }
    .draw_cell_text(label, "centre",
                    col_x_left[[j]], col_x_right[[j]],
                    y_top_in, row_h, vp_w, vp_h,
                    h_lft_in, h_rgt_in, v_top_in,
                    hdr_gp, cs$width_in)
  }
}

# Draw a continuation-marker row
.draw_cont_row <- function(msg, n_group_cols, n_disp_cols,
                            col_x_left, col_x_right,
                            y_top_in, row_h, vp_w, vp_h,
                            h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh) {
  cont_gp <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "continued"), lh)

  # Span starts at first data column
  first_data <- n_group_cols + 1L
  if (first_data > n_disp_cols) first_data <- 1L  # no group cols

  x_start <- col_x_left[[first_data]]
  x_end   <- col_x_right[[n_disp_cols]]
  span_w  <- x_end - x_start

  # Centre the text within the spanned data columns
  x_mid_npc <- (x_start + span_w / 2) / vp_w
  y_npc     <- 1 - (y_top_in + v_top_in) / vp_h

  grid::grid.text(
    label = msg,
    x     = grid::unit(x_mid_npc, "npc"),
    y     = grid::unit(y_npc, "npc"),
    just  = c("centre", "top"),
    gp    = cont_gp
  )
}

# Draw a single cell's text
.draw_cell_text <- function(text, align, x_left, x_right,
                             y_top_in, row_h, vp_w, vp_h,
                             h_lft_in, h_rgt_in, v_top_in,
                             gp, col_width_in, width_cache = NULL) {
  if (nchar(text) == 0L) return(invisible(NULL))

  y_npc <- 1 - (y_top_in + v_top_in) / vp_h

  if (identical(align, "left")) {
    x_npc <- (x_left + h_lft_in) / vp_w
    just  <- c("left", "top")
  } else if (identical(align, "right")) {
    x_npc <- (x_right - h_rgt_in) / vp_w
    just  <- c("right", "top")
  } else {
    # centre
    x_npc <- ((x_left + x_right) / 2) / vp_w
    just  <- c("centre", "top")
  }

  # Re-measure text width in the current (rendering) device using the
  # actual rendering gpar (grid::stringWidth() picks up only the active
  # viewport's gp, which is wrong when `gp` is, e.g., a bold header
  # gpar and the active vp is regular weight).  This corrects font-metric
  # variance between the PDF scratch device used for column-width
  # measurement and the device used for actual rendering (e.g. a PNG
  # device in knitr / RStudio preview mode).
  #
  # Important: cap the clip width at a small tolerance past `col_width_in`
  # so a column that is genuinely too narrow for its content (user set a
  # fixed width below the longest unbreakable token, or a bold header
  # whose measured width exceeded the regular-weight column-width pass)
  # cannot bleed text into the neighboring column and hide its content.
  # Anything past the tolerance gets visually clipped at the column edge,
  # which is a far less destructive failure mode than overlap.
  # Measurement is identical for repeated cell text within one drawDetails
  # call; the optional per-column cache lets the caller deduplicate.
  text_w <- .measure_text_width_in(text, gp, width_cache)
  needed <- text_w + h_lft_in + h_rgt_in

  # X position in parent-viewport inches.
  x_in <- if (identical(align, "left")) {
    x_left + h_lft_in
  } else if (identical(align, "right")) {
    x_right - h_rgt_in
  } else {
    (x_left + x_right) / 2
  }
  y_in <- y_top_in + v_top_in

  if (needed <= col_width_in) {
    # Fast path: the text fits inside its column, so the column width
    # already clips by construction.  Draw directly into the parent
    # viewport and skip the per-cell clip viewport push/pop entirely --
    # for tables of all-fits cells (numeric columns, short categoricals)
    # this saves a viewport per cell.
    grid::grid.text(
      label = text,
      x     = grid::unit(x_in / vp_w, "npc"),
      y     = grid::unit(1 - y_in / vp_h, "npc"),
      just  = just,
      gp    = gp
    )
    return(invisible(NULL))
  }

  # Slow path: text exceeds the column.  Push a clipping viewport so the
  # overflow is clipped at the column edge plus a small tolerance,
  # instead of bleeding into the neighbour.
  bleed_tol_in <- 0.05
  clip_w <- min(col_width_in + bleed_tol_in, needed)
  vp_clip <- grid::viewport(
    x      = grid::unit(x_left / vp_w, "npc"),
    y      = grid::unit(1 - (y_top_in + row_h) / vp_h, "npc"),
    width  = grid::unit(clip_w, "inches"),
    height = grid::unit(row_h, "inches"),
    just   = c("left", "bottom"),
    clip   = "on"
  )
  grid::pushViewport(vp_clip)

  # vp_clip was just constructed with width = clip_w inches and
  # height = row_h inches, so npc=1 inside it is exactly that many inches --
  # no need to convertUnit() to recover those numbers.
  x_local_in <- if (identical(align, "left")) {
    h_lft_in
  } else if (identical(align, "right")) {
    clip_w - h_rgt_in
  } else {
    clip_w / 2
  }
  y_local_in <- row_h - v_top_in

  grid::grid.text(
    label = text,
    x     = grid::unit(x_local_in, "inches"),
    y     = grid::unit(y_local_in, "inches"),
    just  = just,
    gp    = gp
  )

  grid::popViewport()
}
