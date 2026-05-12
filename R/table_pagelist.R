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
  margins         = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  padding         = grid::unit(0.5, "lines"),
  header_rule     = FALSE,
  footer_rule     = FALSE,
  caption_just    = "left",
  footnote_just   = "left",
  gp              = grid::gpar(),
  overflow_action = "error"
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
#' @param page_num Glue template string for page numbering.
#' @return A list of page spec lists, each with at least `$content` (a grob).
#' @keywords internal
tfl_table_to_pagelist <- function(tbl, pg_width, pg_height, dots,
                                   page_num = "Page {i} of {n}") {
  if (is.null(tbl$sub_tfl)) {
    .tfl_table_to_pagelist_default(tbl, pg_width, pg_height, dots, page_num)
  } else {
    .tfl_table_to_pagelist_sub_tfl(tbl, pg_width, pg_height, dots, page_num)
  }
}

# Sub-table dispatch: split data by sub_tfl, run the default pipeline once per
# group with that group's caption (base + prefix + suffix), and concatenate
# the resulting pages. Available content height varies per group because the
# caption suffix has variable line count, so each group must re-run the full
# measurement pipeline; recursion handles that naturally.
#' @keywords internal
.tfl_table_to_pagelist_sub_tfl <- function(tbl, pg_width, pg_height, dots,
                                            page_num) {
  groups <- .compute_sub_tfl_groups(tbl$data, tbl$sub_tfl)
  pages  <- list()
  for (g in groups) {
    sub_tbl <- tbl
    keep_cols <- setdiff(names(tbl$data), tbl$sub_tfl)
    sub_tbl$data <- tbl$data[g$row_idx, keep_cols, drop = FALSE]
    sub_tbl$group_vars <- setdiff(tbl$group_vars, tbl$sub_tfl)
    sub_tbl <- .strip_sub_tfl_cols(sub_tbl)
    sub_tbl$sub_tfl <- NULL  # prevent recursion

    suffix <- .format_sub_tfl_caption(tbl, g$values)
    sub_dots <- dots
    sub_dots$caption <- .apply_sub_tfl_caption(dots$caption, suffix,
                                               tbl$sub_tfl_prefix)

    sub_pages <- tfl_table_to_pagelist(sub_tbl, pg_width, pg_height,
                                       sub_dots, page_num)
    sub_pages <- lapply(sub_pages, .attach_page_caption,
                        caption = sub_dots$caption)
    pages <- c(pages, sub_pages)
  }
  pages
}

# Attach a caption to a single page spec. Used by .tfl_table_to_pagelist_sub_tfl
# to ensure each sub-page carries its caption when build_page_args() merges.
#' @keywords internal
.attach_page_caption <- function(page, caption) {
  page$caption <- caption
  page
}

#' @keywords internal
.tfl_table_to_pagelist_default <- function(tbl, pg_width, pg_height, dots,
                                            page_num) {
  # --- Step 1: Extract layout args from dots ---
  # Use explicit NULL checks instead of %||% for arguments that can legitimately

  # be FALSE or other falsy values (e.g. header_rule = FALSE).  %||% treats NULL
  # as missing but would also drop FALSE if the default were ever changed to TRUE.
  .dot <- function(key) {
    if (!is.null(dots[[key]])) dots[[key]] else .tfl_page_defaults[[key]]
  }
  margins         <- .dot("margins")
  padding         <- .dot("padding")
  header_rule     <- .dot("header_rule")
  footer_rule     <- .dot("footer_rule")
  cap_just        <- .dot("caption_just")
  fn_just         <- .dot("footnote_just")
  gp_page         <- .dot("gp")
  overflow_action <- .dot("overflow_action")
  overflow_action <- match.arg(overflow_action, c("error", "warn"))

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

  # --- Step 4-6: Compute column widths, measure row heights, paginate ---
  # Under col_split_strategy = "balanced", a row whose wrapped height exceeds
  # the available page content height triggers a retry: the bottleneck
  # column's minimum width is raised by `step_in` and the whole width-
  # measurement-pagination loop runs again.  Up to `row_overflow_max_retries`
  # retries (default 5; 0L disables).  After the cap the final paginate_rows
  # call is made with the user's overflow_action so the standard error/warn
  # path fires.
  resolved_cols_0   <- resolved_cols     # pre-width snapshot for re-runs
  breaks            <- tbl$wrap_breaks %||% wrap_breaks_default()
  wrap_extra_pad_in <- if (!is.null(tbl$wrap_extra_padding)) {
    .height_in(tbl$wrap_extra_padding)
  } else 0
  strategy        <- tbl$col_split_strategy %||% "balanced"
  max_retries     <- as.integer(tbl$row_overflow_max_retries %||% 5L)
  use_retry_loop  <- identical(strategy, "balanced") && max_retries > 0L
  floor_step_in   <- 0.25                # how much to widen on each retry
  floor_overrides <- numeric(0L)
  names(floor_overrides) <- character(0L)
  retries         <- 0L

  # Per-iteration helper: opens a fresh row-height scratch device, runs
  # the measurement + pagination phase, closes the scratch device, and
  # returns (row_pages, cell_h_mat, cont_row_h).  The scratch device's
  # lifecycle is fully contained inside this helper so the surrounding
  # retry loop never holds a viewport across a compute_col_widths()
  # call (compute_col_widths() opens its own scratch devices internally).
  .run_pagination_iter <- function(resolved_cols, collect_overflows) {
    scratch_file_rh <- tempfile(fileext = ".pdf")
    grDevices::pdf(scratch_file_rh, width = pg_width, height = pg_height)
    rh_outer_vp <- .make_outer_vp(margins)
    grid::pushViewport(rh_outer_vp)
    on.exit({
      grid::popViewport()
      grDevices::dev.off()
      unlink(scratch_file_rh)
    }, add = TRUE)

    header_row_h <- if (tbl$show_col_names) {
      .measure_header_row_height(resolved_cols, tbl$gp, tbl$cell_padding,
                                 tbl$line_height, breaks = breaks,
                                 wrap_extra_pad_in = wrap_extra_pad_in)
    } else 0

    cell_h_mat <- measure_row_heights_tbl(
      tbl$data, resolved_cols, tbl$gp, tbl$cell_padding,
      tbl$na_string, tbl$line_height, tbl$max_measure_rows,
      breaks = breaks,
      wrap_extra_pad_in = wrap_extra_pad_in
    )

    cont_row_h <- max(
      .measure_cont_row_height(tbl$row_cont_msg[[1L]], tbl$gp, tbl$cell_padding,
                               tbl$line_height),
      .measure_cont_row_height(tbl$row_cont_msg[[2L]], tbl$gp, tbl$cell_padding,
                               tbl$line_height)
    )

    pr_args <- list(
      tbl$data, cell_h_mat, resolved_cols, tbl$group_vars,
      cont_row_h, header_row_h, ch,
      tbl$row_cont_msg, tbl$group_rule,
      suppress_repeated_groups = isTRUE(tbl$suppress_repeated_groups),
      collect_overflows        = collect_overflows
    )
    if (!collect_overflows) {
      pr_args$overflow_action <- overflow_action
    }
    pr_res <- do.call(paginate_rows, pr_args)
    list(
      pr_res     = pr_res,
      cell_h_mat = cell_h_mat,
      cont_row_h = cont_row_h
    )
  }

  repeat {
    col_result <- compute_col_widths(
      resolved_cols_0, tbl$data, cw, tbl, pg_width, pg_height, margins,
      overflow_action = overflow_action,
      floor_overrides = floor_overrides
    )
    resolved_cols <- col_result$resolved_cols
    col_groups    <- col_result$col_groups
    has_col_split <- length(col_groups) > 1L

    # Second pass: if a column split was detected and col_cont_msg labels
    # will appear, reserve half a character-height at each labelled
    # viewport edge so table content does not overlap the rotated
    # annotations.  Labels appear on every column page that is NOT first
    # (left side) and NOT last (right side); both conditions arise
    # whenever n_col_groups > 1, so reduce cw by the relevant label
    # half-widths and re-compute with the tighter constraint.
    if (has_col_split && !is.null(tbl$col_cont_msg)) {
      hw     <- col_result$col_cont_label_half_w
      cw_adj <- cw
      if (!is.null(tbl$col_cont_msg[[1L]])) cw_adj <- cw_adj - hw
      if (!is.null(tbl$col_cont_msg[[2L]])) cw_adj <- cw_adj - hw
      col_result <- compute_col_widths(
        resolved_cols_0, tbl$data, cw_adj, tbl, pg_width, pg_height, margins,
        overflow_action   = overflow_action,
        validate_overflow = FALSE,
        floor_overrides   = floor_overrides
      )
      resolved_cols <- col_result$resolved_cols
      col_groups    <- col_result$col_groups
      has_col_split <- length(col_groups) > 1L
    }

    if (use_retry_loop && retries < max_retries) {
      iter_res <- .run_pagination_iter(resolved_cols, collect_overflows = TRUE)
      if (length(iter_res$pr_res$overflows) == 0L) {
        row_pages  <- iter_res$pr_res$pages
        cell_h_mat <- iter_res$cell_h_mat
        cont_row_h <- iter_res$cont_row_h
        break
      }
      # Raise the bottleneck column's floor for the next retry.
      for (ev in iter_res$pr_res$overflows) {
        bot_j <- ev$bottleneck_col
        if (bot_j < 1L || bot_j > length(resolved_cols)) next
        cs <- resolved_cols[[bot_j]]
        cur_w <- cs$width_in
        new_floor <- cur_w + floor_step_in
        prev <- if (cs$col %in% names(floor_overrides)) {
          floor_overrides[[cs$col]]
        } else {
          0
        }
        floor_overrides[cs$col] <- max(prev, new_floor)
      }
      retries <- retries + 1L
      # Loop back: recompute widths with the new floors.
    } else {
      # No retries left (or wrap_first mode): make the final call with the
      # user's overflow_action so error/warn fires through the normal path.
      iter_res <- .run_pagination_iter(resolved_cols, collect_overflows = FALSE)
      row_pages  <- iter_res$pr_res
      cell_h_mat <- iter_res$cell_h_mat
      cont_row_h <- iter_res$cont_row_h
      break
    }
  }

  # --- Step 7: Assemble page specs ---
  n_rp <- length(row_pages)
  n_cg <- length(col_groups)
  pages <- vector("list", n_rp * n_cg)
  idx   <- 1L

  # Shared per-resolved_cols clip-width cache.  Every page-grob built below
  # holds a reference to the SAME list of envs, so .draw_cell_text() can
  # reuse measurements across pages of the same tfl_table (one entry per
  # unique cell text per column).  Envs are reference-typed, so memory is
  # not duplicated per grob.
  clip_width_caches <- lapply(seq_along(resolved_cols), function(k) {
    new.env(hash = TRUE, parent = emptyenv())
  })

  for (rp in seq_len(n_rp)) {
    for (cg in seq_len(n_cg)) {
      grob <- build_table_grob(
        row_page             = row_pages[[rp]],
        col_group_idx        = col_groups[[cg]],
        n_group_cols         = n_group_cols,
        resolved_cols        = resolved_cols,
        tbl                  = tbl,
        cell_heights_in_mat  = cell_h_mat,
        cont_row_h_in        = cont_row_h,
        is_first_col_page    = (cg == 1L),
        is_last_col_page     = (cg == n_cg),
        clip_width_caches    = clip_width_caches
      )
      page_spec <- list(content = grob)
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
#' Opens a scratch device, measures annotation section heights using the
#' same infrastructure as export_tfl_page(), and returns available width and
#' height in inches.
#'
#' @keywords internal
compute_table_content_area <- function(pg_width, pg_height, margins, padding,
                                       header_rule, footer_rule,
                                       annot, gp_page, cap_just, fn_just) {
  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  on.exit(grDevices::dev.off(), add = TRUE)

  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)

  vp_w <- .width_in(grid::unit(1, "npc"))
  vp_h <- .height_in(grid::unit(1, "npc"))
  pad_in <- .height_in(padding)

  # Normalise annotation texts
  norm <- lapply(annot, normalize_text)

  # Resolve gp for caption and footnote so we can word-wrap
  caption_gp  <- resolve_gp(gp_page, "caption",  "caption")
  footnote_gp <- resolve_gp(gp_page, "footnote", "footnote")
  norm$caption  <- wrap_normalized_text(norm$caption,  caption_gp,  vp_w)
  norm$footnote <- wrap_normalized_text(norm$footnote, footnote_gp, vp_w)

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
