# table_pagelist.R — Orchestration: tfl_table → list of page specs
#
# Entry point called by export_tfl() when x is a "tfl_table" object.
#
# Function hierarchy:
#   tfl_table_to_pagelist()
#     compute_table_content_area()   — scratch device, reuses page-layout helpers
#     resolve_col_specs()            — table_columns.R
#     compute_col_widths()           — table_columns.R
#     measure_row_heights_tbl()      — table_rows.R
#     paginate_rows()                — table_rows.R
#     build_table_grob()             — table_draw.R

# Default values mirroring export_tfl_page() for use when dots are absent
.tfl_page_defaults <- list(
  margins        = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  padding        = grid::unit(0.5, "lines"),
  header_rule    = FALSE,
  footer_rule    = FALSE,
  caption_just   = "left",
  footnote_just  = "left",
  gp             = grid::gpar()
)

# ---------------------------------------------------------------------------
# tfl_table_to_pagelist() — main entry point
# ---------------------------------------------------------------------------

#' Convert a tfl_table object to a list of page specification lists
#'
#' Called internally by [export_tfl()] when `x` is a `"tfl_table"`.
#'
#' @param tbl A `"tfl_table"` object.
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots The `list(...)` from [export_tfl()].
#' @return A list of page spec lists, each with at least `$content` (a grob).
#' @keywords internal
tfl_table_to_pagelist <- function(tbl, pg_width, pg_height, dots,
                                   page_num = "Page {i} of {n}") {

  # --- Step 1: Extract layout args from dots ---
  margins      <- dots$margins      %||% .tfl_page_defaults$margins
  padding      <- dots$padding      %||% .tfl_page_defaults$padding
  header_rule  <- dots$header_rule  %||% .tfl_page_defaults$header_rule
  footer_rule  <- dots$footer_rule  %||% .tfl_page_defaults$footer_rule
  cap_just     <- dots$caption_just %||% .tfl_page_defaults$caption_just
  fn_just      <- dots$footnote_just %||% .tfl_page_defaults$footnote_just
  gp_page      <- dots$gp           %||% .tfl_page_defaults$gp

  annot <- list(
    header_left   = dots$header_left,
    header_center = dots$header_center,
    header_right  = dots$header_right,
    caption       = dots$caption,
    footnote      = dots$footnote,
    footer_left   = dots$footer_left,
    footer_center = dots$footer_center,
    footer_right  = dots$footer_right
  )

  # If page_num will supply footer_right (and it is not already set), account
  # for the footer section in the content-area calculation so that pagination
  # uses the same available height that export_tfl_page() will actually have.
  if (is.null(annot$footer_right) && !is.null(page_num)) {
    annot$footer_right <- "Page 1 of 1"   # representative dummy for sizing
  }

  # --- Step 2: Measure available content area ---
  content_dims <- compute_table_content_area(
    pg_width, pg_height, margins, padding,
    header_rule, footer_rule, annot, gp_page, cap_just, fn_just
  )
  cw <- content_dims$width
  ch <- content_dims$height

  # --- Step 3: Resolve column specs ---
  resolved_cols <- resolve_col_specs(tbl)
  n_group_cols  <- length(tbl$group_vars)

  # --- Step 4: Compute column widths and determine column groups ---
  col_result <- compute_col_widths(
    resolved_cols, tbl$data, cw, tbl, pg_width, pg_height, margins
  )
  resolved_cols   <- col_result$resolved_cols   # widths now set in inches
  col_groups      <- col_result$col_groups       # list of integer vectors
  has_col_split   <- length(col_groups) > 1L

  # --- Step 5: Measure row heights ---
  # Open scratch device once for height measurement
  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  on.exit(grDevices::dev.off(), add = FALSE)

  # Push outer_vp for measurement context
  outer_vp <- .make_outer_vp(margins, pg_width, pg_height)
  grid::pushViewport(outer_vp)

  header_row_h <- if (tbl$show_col_names) {
    .measure_header_row_height(resolved_cols, tbl$gp, tbl$cell_padding,
                               tbl$line_height)
  } else 0

  row_heights <- measure_row_heights_tbl(
    tbl$data, resolved_cols, tbl$gp, tbl$cell_padding,
    tbl$na_string, tbl$line_height, tbl$max_measure_rows
  )

  # cont_row_h: height of a (continued) row — measure the cont message text
  cont_row_h <- max(
    .measure_cont_row_height(tbl$row_cont_msg[[1L]], tbl$gp, tbl$cell_padding,
                             tbl$line_height),
    .measure_cont_row_height(tbl$row_cont_msg[[2L]], tbl$gp, tbl$cell_padding,
                             tbl$line_height)
  )

  # Rule heights: rules are drawn within existing space (0 height), but
  # we need to know if we should budget for them when computing page capacity.
  # Approach: rules are infinitesimally thin — they don't consume row space.

  grid::popViewport()
  grDevices::dev.off()
  on.exit(NULL)  # clear on.exit

  # --- Step 6: Paginate rows ---
  row_pages <- paginate_rows(
    tbl$data, row_heights, cont_row_h, header_row_h, ch,
    tbl$group_vars, tbl$row_cont_msg, tbl$group_rule
  )

  # --- Step 7: Assemble page specs ---
  n_rp <- length(row_pages)
  n_cg <- length(col_groups)
  pages <- vector("list", n_rp * n_cg)
  idx   <- 1L

  for (rp in seq_len(n_rp)) {
    for (cg in seq_len(n_cg)) {
      grob <- build_table_grob(
        row_page       = row_pages[[rp]],
        col_group_idx  = col_groups[[cg]],
        n_group_cols   = n_group_cols,
        resolved_cols  = resolved_cols,
        tbl            = tbl,
        row_heights_in = row_heights,
        cont_row_h_in  = cont_row_h
      )
      page_spec <- list(content = grob)
      # Inject col_cont_msg into footer_center only on col-split pages
      # where footer_center is not already set in dots
      if (has_col_split && !is.null(tbl$col_cont_msg) &&
          is.null(dots$footer_center)) {
        page_spec$footer_center <- tbl$col_cont_msg
      }
      pages[[idx]] <- page_spec
      idx <- idx + 1L
    }
  }

  pages
}

# ---------------------------------------------------------------------------
# compute_table_content_area() — scratch device annotation measurement
# ---------------------------------------------------------------------------

#' Compute available content area for a tfl_table page
#'
#' Opens a scratch PDF device, measures annotation section heights using the
#' same infrastructure as export_tfl_page(), and returns available width and
#' height in inches.
#'
#' @keywords internal
compute_table_content_area <- function(pg_width, pg_height, margins, padding,
                                       header_rule, footer_rule,
                                       annot, gp_page, cap_just, fn_just) {
  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  on.exit(grDevices::dev.off(), add = TRUE)

  outer_vp <- .make_outer_vp(margins, pg_width, pg_height)
  grid::pushViewport(outer_vp)

  vp_w <- grid::convertWidth( grid::unit(1, "npc"), "inches", valueOnly = TRUE)
  vp_h <- grid::convertHeight(grid::unit(1, "npc"), "inches", valueOnly = TRUE)
  pad_in <- grid::convertHeight(padding, "inches", valueOnly = TRUE)

  # Normalise annotation texts
  norm <- lapply(annot, normalize_text)

  # Build section grobs and measure heights (reuses existing helpers)
  grobs <- build_section_grobs(norm, lapply(names(norm), function(el) {
    sec <- sub("_(left|center|right)$", "", el)
    resolve_gp(gp_page, sec, el)
  }) |> stats::setNames(names(norm)), cap_just, fn_just)

  heights <- measure_section_heights(
    list(header_left   = grobs$header_left,
         header_center = grobs$header_center,
         header_right  = grobs$header_right),
    grobs$caption,
    grobs$footnote,
    list(footer_left   = grobs$footer_left,
         footer_center = grobs$footer_center,
         footer_right  = grobs$footer_right),
    norm
  )

  # Determine which sections are present (same logic as export_tfl_page)
  present <- c(
    header   = any(!vapply(annot[c("header_left","header_center","header_right")],
                           is.null, logical(1L))),
    caption  = !is.null(annot$caption),
    content  = TRUE,  # the table is always present
    footnote = !is.null(annot$footnote),
    footer   = any(!vapply(annot[c("footer_left","footer_center","footer_right")],
                           is.null, logical(1L)))
  )

  n_gaps <- max(0L, sum(present) - 1L)
  used_h <- heights$header + heights$caption + heights$footnote + heights$footer
  avail_h <- vp_h - used_h - n_gaps * pad_in

  grid::popViewport()

  list(width = vp_w, height = max(avail_h, 0))
}
