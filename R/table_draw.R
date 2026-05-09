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

  # Use cached heights from the pagination phase (ensures layout consistency).
  # Fall back to re-measurement only when cache is absent.
  rows   <- row_page$rows
  n_rows <- length(rows)

  lh <- tbl$line_height %||% 1.05   # defensive fallback for old grob objects

  # Header row height
  header_row_h <- if (tbl$show_col_names) {
    hdr_gp <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"), lh)
    max(vapply(page_cols, function(cs) {
      nlines <- max(1L, length(strsplit(cs$label, "\n", fixed = TRUE)[[1L]]))
      grob   <- grid::textGrob(cs$label, gp = hdr_gp)
      h1     <- .height_in(grid::grobHeight(grob))
      h2     <- nlines * .height_in(grid::stringHeight("M"))
      max(h1, h2)
    }, numeric(1L))) + v_pad_in
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

  group_vars       <- tbl$group_vars
  simplify_rowspan <- isTRUE(tbl$simplify_rowspan)

  # Precompute the per-page suppression matrix.  Used both for cell-content
  # blanking (always, when suppress_repeated_groups is set) and — only when
  # simplify_rowspan = TRUE — for span-aware row heights, span clipping,
  # and within-span row-rule suppression.
  suppress_mat <- if (isTRUE(tbl$suppress_repeated_groups) &&
                      length(group_vars) > 0L) {
    .compute_cell_suppression(data, group_vars, rows)
  } else NULL

  # The row-height resolver returns the per-row max over all columns when
  # given suppress_mat = NULL (the historical layout).  Pass NULL when
  # simplify_rowspan = FALSE so behaviour matches the pre-#29 release.
  row_h_suppress <- if (simplify_rowspan) suppress_mat else NULL

  # Per-page row heights — prefer the heights that pagination committed; if
  # absent, recompute from the cached cell-height matrix using the same
  # algorithm pagination uses.  As a final fallback, build a per-page
  # matrix on the fly (covers grobs assembled outside the normal pipeline).
  row_h_vec <- if (!is.null(row_page$row_heights_in) &&
                   length(row_page$row_heights_in) == n_rows) {
    row_page$row_heights_in
  } else if (!is.null(x$cell_heights_in_mat) && !is.null(x$resolved_cols)) {
    .compute_page_row_heights(
      x$cell_heights_in_mat, rows, x$resolved_cols, group_vars, row_h_suppress
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
        disp_s <- if (cs$wrap && !is.null(cs$width_in)) {
          .wrap_text(s, cs$width_in - h_lft_in - h_rgt_in, gp_c)
        } else s
        nlines <- max(1L, length(strsplit(disp_s, "\n", fixed = TRUE)[[1L]]))
        grob   <- grid::textGrob(disp_s, gp = gp_c)
        h1     <- .height_in(grid::grobHeight(grob))
        h2     <- nlines * .height_in(grid::stringHeight("M"))
        fallback_mat[ri, j] <- max(h1, h2) + v_pad_in
      }
    }
    .compute_page_row_heights(
      fallback_mat, seq_len(n_rows), page_cols, group_vars, row_h_suppress
    )
  }

  # Group-rule metadata.  The two helpers differ:
  #   .compute_group_sizes()       — innermost-group size (historical).
  #     Suppresses the rule whenever the new innermost group has 1 row,
  #     even if an outer level changed at this transition.
  #   .compute_group_rule_info()  — outermost-changing-level size + level.
  #     Used when simplify_rowspan = TRUE to (a) draw rules at outer-level
  #     boundaries that the historical helper missed and (b) start the
  #     rule line at the changing column instead of at column 1.
  group_sizes      <- NULL
  group_rule_info  <- NULL
  if (tbl$group_rule && length(group_vars) > 0L) {
    if (simplify_rowspan) {
      group_rule_info <- .compute_group_rule_info(data, group_vars)
    } else {
      group_sizes <- .compute_group_sizes(data, group_vars)
    }
  }

  # Precompute span ends per group column on this page so non-suppressed
  # group cells can be drawn with a clip viewport that covers the whole
  # span.  span_end_mat[ri, g] is the last row index in the same span as ri
  # for group column g; only meaningful when simplify_rowspan = TRUE.
  span_end_mat <- if (simplify_rowspan && !is.null(suppress_mat)) {
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
                     h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh)
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

  for (ri in seq_len(n_rows)) {
    i     <- rows[[ri]]
    row_h <- row_h_vec[[ri]]

    # Group rule before this row (if it starts a group and is not the first
    # visible row).  Visibility and width depend on simplify_rowspan:
    #   * FALSE (default) — historical: rule is full table width and is
    #     suppressed when the *innermost* group at this start has size 1.
    #   * TRUE — rule is drawn at every transition (no size suppression);
    #     it starts at the column corresponding to the outermost level
    #     that actually changed at this boundary, so unchanged outer
    #     columns through which the label is flowing aren't sliced.
    if (i %in% grp_starts && ri > 1L) group_fill_idx <- group_fill_idx + 1L
    if (tbl$group_rule && i %in% grp_starts && y_cursor > header_row_h + 1e-6) {
      draw_rule       <- FALSE
      rule_start_col  <- 1L
      if (simplify_rowspan && !is.null(group_rule_info)) {
        # Always draw at every transition; pick start column from the
        # outermost-changing level reported by the helper.
        gk <- group_rule_info$levels[as.character(i)]
        if (!is.na(gk)) {
          draw_rule      <- TRUE
          rule_start_col <- min(as.integer(gk), n_disp_cols)
        }
      } else if (!is.null(group_sizes)) {
        # Historical visibility check.
        gs <- group_sizes[as.character(i)]
        draw_rule <- is.na(gs) || gs > 1L
      } else {
        draw_rule <- TRUE
      }
      if (draw_rule) {
        rule_gp     <- .resolve_table_gp(gp_tbl, "group_rule")
        y_rule_npc  <- 1 - y_cursor / vp_h
        x_left_npc  <- col_x_left[[rule_start_col]] / vp_w
        x_right_npc <- col_x_right[[n_disp_cols]]   / vp_w
        grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                         y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                         gp = rule_gp)
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
      cs      <- page_cols[[j]]
      raw_val <- data[[cs$col]][i]
      cell_str <- .fmt_cell(raw_val, na_str)

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

      # Resolve cell gpar (with lineheight applied)
      cell_gp <- .gp_with_lineheight(.resolve_table_cell_gp(gp_tbl, cs$is_group_col), lh)

      # For wrap-eligible columns, apply word-wrapping before drawing
      display_str <- if (cs$wrap && nzchar(cell_str) && !is.null(cs$width_in)) {
        .wrap_text(cell_str, cs$width_in - h_lft_in - h_rgt_in, cell_gp)
      } else {
        cell_str
      }

      .draw_cell_text(display_str, cs$align,
                      col_x_left[[j]], col_x_right[[j]],
                      y_cursor, clip_h, vp_w, vp_h,
                      h_lft_in, h_rgt_in, v_top_in,
                      cell_gp, cs$width_in)
    }

    y_cursor <- y_cursor + row_h

    # Row rule between data rows (not after last).  When simplify_rowspan
    # is TRUE, suppress the rule if the next row is part of a multi-row
    # group span starting at or before this row — drawing a horizontal
    # line through a label that flows downward would visually slice it.
    # When simplify_rowspan is FALSE (default), draw rules between every
    # pair of data rows (the historical behaviour).
    rule_inside_span <- simplify_rowspan && !is.null(suppress_mat) &&
                        ri < n_rows && any(suppress_mat[ri + 1L, ])
    if (tbl$row_rule && ri < n_rows && !rule_inside_span) {
      rule_gp     <- .resolve_table_gp(gp_tbl, "row_rule")
      y_rule_npc  <- 1 - y_cursor / vp_h
      x_left_npc  <- col_x_left[[1L]]          / vp_w
      x_right_npc <- col_x_right[[n_disp_cols]] / vp_w
      grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                       y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                       gp = rule_gp)
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

# Draw the column header row
.draw_header_row <- function(page_cols, col_x_left, col_x_right, col_widths_in,
                              y_top_in, row_h, vp_w, vp_h,
                              h_lft_in, h_rgt_in, v_top_in, gp_tbl, lh) {
  hdr_gp <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"), lh)
  for (j in seq_along(page_cols)) {
    cs <- page_cols[[j]]
    .draw_cell_text(cs$label, "centre",
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
                             gp, col_width_in) {
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

  # Re-measure text width in the current (rendering) device and use the wider

  # of the cached column width and the measured text width.  This prevents
  # clipping when font metrics differ between the PDF scratch device used for
  # column-width measurement and the device used for actual rendering (e.g.
  # a PNG device in knitr/RStudio preview mode).
  text_w <- .width_in(grid::stringWidth(text))
  clip_w <- max(col_width_in, text_w + h_lft_in + h_rgt_in)

  # Clip to column width by using a clipping viewport
  vp_clip <- grid::viewport(
    x      = grid::unit(x_left / vp_w, "npc"),
    y      = grid::unit(1 - (y_top_in + row_h) / vp_h, "npc"),
    width  = grid::unit(clip_w, "inches"),
    height = grid::unit(row_h, "inches"),
    just   = c("left", "bottom"),
    clip   = "on"
  )
  grid::pushViewport(vp_clip)

  # Re-express x, y relative to clip viewport
  vp_w2 <- .width_in(grid::unit(1, "npc"))
  vp_h2 <- .height_in(grid::unit(1, "npc"))

  x_local_in <- if (identical(align, "left")) {
    h_lft_in
  } else if (identical(align, "right")) {
    vp_w2 - h_rgt_in
  } else {
    vp_w2 / 2
  }
  y_local_in <- vp_h2 - v_top_in

  grid::grid.text(
    label = text,
    x     = grid::unit(x_local_in, "inches"),
    y     = grid::unit(y_local_in, "inches"),
    just  = just,
    gp    = gp
  )

  grid::popViewport()
}
