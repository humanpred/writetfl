# table_draw.R — Table grob construction and drawDetails dispatch
#
# build_table_grob()       — assembles a "tfl_table_grob" gTree
# drawDetails.tfl_table_grob() — draws the table when rendered

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
                             row_heights_in    = NULL,
                             cont_row_h_in     = NULL,
                             is_first_col_page = TRUE,
                             is_last_col_page  = TRUE) {
  # Subset to display columns for this page
  page_cols <- resolved_cols[col_group_idx]

  grid::gTree(
    row_page          = row_page,
    col_group_idx     = col_group_idx,
    n_group_cols      = n_group_cols,
    page_cols         = page_cols,
    tbl               = tbl,
    row_heights_in    = row_heights_in,    # cached from paginate phase
    cont_row_h_in     = cont_row_h_in,     # cached from paginate phase
    is_first_col_page = is_first_col_page, # FALSE when prior col pages exist
    is_last_col_page  = is_last_col_page,  # FALSE when more col pages follow
    cl                = "tfl_table_grob"
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

  # Data row heights — prefer cached values
  row_h_vec <- if (!is.null(x$row_heights_in) &&
                   length(x$row_heights_in) >= (if (n_rows > 0L) max(rows) else 0L)) {
    x$row_heights_in[rows]
  } else {
    vapply(rows, function(i) {
      max(vapply(page_cols, function(cs) {
        s    <- .fmt_cell(data[[cs$col]][i], na_str)
        gp_c <- .gp_with_lineheight(.resolve_table_cell_gp(gp_tbl, cs$is_group_col), lh)
        disp_s <- if (cs$wrap && !is.null(cs$width_in)) {
          .wrap_text(s, cs$width_in - h_lft_in - h_rgt_in, gp_c)
        } else s
        nlines <- max(1L, length(strsplit(disp_s, "\n", fixed = TRUE)[[1L]]))
        grob   <- grid::textGrob(disp_s, gp = gp_c)
        h1     <- .height_in(grid::grobHeight(grob))
        h2     <- nlines * .height_in(grid::stringHeight("M"))
        max(h1, h2)
      }, numeric(1L))) + v_pad_in
    }, numeric(1L))
  }

  # Precompute group sizes — group rules are suppressed for single-row groups
  group_vars  <- tbl$group_vars
  group_sizes <- if (tbl$group_rule && length(group_vars) > 0L) {
    .compute_group_sizes(data, group_vars)
  } else NULL

  # --- Build row y-positions (top-to-bottom, in inches from top of vp) ---
  # In grid: y=0 is bottom, y=1 is top.
  # We track y_top_in = distance from TOP of viewport (increasing downward).

  y_cursor <- 0   # distance from top in inches

  # Draw column header row
  if (tbl$show_col_names) {
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
  grp_starts   <- row_page$group_starts
  # Track last shown group values for repeat suppression
  last_grp_val <- if (tbl$suppress_repeated_groups && length(group_vars) > 0L) {
    rep(list(NULL), length(group_vars)) |> stats::setNames(group_vars)
  } else NULL

  for (ri in seq_len(n_rows)) {
    i     <- rows[[ri]]
    row_h <- row_h_vec[[ri]]

    # Group rule before this row (if it starts a group, not the first visible row,
    # and the group has more than one row in the full data)
    if (tbl$group_rule && i %in% grp_starts && y_cursor > header_row_h + 1e-6) {
      gs <- if (!is.null(group_sizes)) group_sizes[as.character(i)] else NA_integer_
      if (is.na(gs) || gs > 1L) {
        rule_gp     <- .resolve_table_gp(gp_tbl, "group_rule")
        y_rule_npc  <- 1 - y_cursor / vp_h
        x_left_npc  <- col_x_left[[1L]]          / vp_w
        x_right_npc <- col_x_right[[n_disp_cols]] / vp_w
        grid::grid.lines(x  = grid::unit(c(x_left_npc, x_right_npc), "npc"),
                         y  = grid::unit(c(y_rule_npc, y_rule_npc), "npc"),
                         gp = rule_gp)
      }
    }

    # Draw data row
    for (j in seq_len(n_disp_cols)) {
      cs      <- page_cols[[j]]
      raw_val <- data[[cs$col]][i]
      cell_str <- .fmt_cell(raw_val, na_str)

      # Group repeat suppression
      if (tbl$suppress_repeated_groups && cs$is_group_col &&
          !is.null(last_grp_val)) {
        prev <- last_grp_val[[cs$col]]
        if (!is.null(prev) && identical(prev, raw_val)) {
          cell_str <- ""
        } else {
          last_grp_val[[cs$col]] <- raw_val
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
                      y_cursor, row_h, vp_w, vp_h,
                      h_lft_in, h_rgt_in, v_top_in,
                      cell_gp, cs$width_in)
    }

    y_cursor <- y_cursor + row_h
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
    # One line-height of spacing between table edge and text centre
    line_h_in <- .height_in(grid::stringHeight("M"))

    # Right side: clockwise 90° when columns continue on a subsequent page
    if (!is_last_col_page) {
      x_npc <- (col_x_right[[n_disp_cols]] + line_h_in) / vp_w
      grid::grid.text(
        label = tbl$col_cont_msg,
        x     = grid::unit(x_npc, "npc"),
        y     = grid::unit(0.5, "npc"),
        rot   = -90,
        just  = "centre",
        gp    = col_cont_gp
      )
    }

    # Left side: counter-clockwise 90° when columns continue from a prior page
    if (!is_first_col_page) {
      x_npc <- (col_x_left[[1L]] - line_h_in) / vp_w
      grid::grid.text(
        label = tbl$col_cont_msg,
        x     = grid::unit(x_npc, "npc"),
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

  # Clip to column width by using a clipping viewport
  vp_clip <- grid::viewport(
    x      = grid::unit(x_left / vp_w, "npc"),
    y      = grid::unit(1 - (y_top_in + row_h) / vp_h, "npc"),
    width  = grid::unit(col_width_in, "inches"),
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
