# table_columns.R — Column specification, width computation, and column pagination
#
# Functions:
#   resolve_col_specs()      — merge tfl_colspec + flat tfl_table() args per column
#   compute_col_widths()     — auto-size, relative, fixed, wrap; returns widths + groups
#   paginate_cols()          — split column indices into per-page groups
#
# The text-wrap narrowing pass that used to live here as .apply_col_wrapping()
# now lives in R/wrap.R as .compute_wrapped_widths() so it can also be used
# (and disabled) as a coherent module.

# ---------------------------------------------------------------------------
# resolve_col_specs() — merge tfl_colspec + flat args into unified list
# ---------------------------------------------------------------------------

#' Resolve column specifications into a unified per-column list
#'
#' Returns a list (one element per column in source order) where each element
#' is a named list: col, label, width (unit/numeric/NULL), align, wrap,
#' gp (gpar or NULL), is_group_col.
#'
#' @keywords internal
resolve_col_specs <- function(tbl) {
  col_names  <- names(tbl$data)
  grp_vars   <- tbl$group_vars
  spec_index <- if (!is.null(tbl$cols)) {
    stats::setNames(tbl$cols, vapply(tbl$cols, `[[`, "", "col"))
  } else list()

  lapply(col_names, function(cn) {
    spec         <- spec_index[[cn]]
    is_group_col <- cn %in% grp_vars

    # Width: tfl_colspec > col_widths flat arg > NULL (auto)
    width <- spec$width %||% .nlookup(tbl$col_widths, cn)

    # Label: tfl_colspec > col_labels flat arg > column name
    label <- spec$label %||% .nlookup(tbl$col_labels, cn) %||% cn

    # Align: tfl_colspec > col_align flat arg > type-based default
    align <- spec$align %||% .nlookup(tbl$col_align, cn) %||%
      .default_align(tbl$data[[cn]])

    # Wrap: tfl_colspec > wrap_cols flat arg.
    # Result is logical of length 1: TRUE / FALSE / NA.  NA means "auto-detect
    # based on whether the column contains a break character" and is resolved
    # to TRUE / FALSE inside compute_col_widths() once the data and break spec
    # are in scope.
    spec_wrap <- spec$wrap
    wrap <- if (!is.null(spec_wrap) && !is.na(spec_wrap)) {
      as.logical(spec_wrap)
    } else {
      w <- tbl$wrap_cols
      if (identical(w, "auto")) {
        if (is_group_col) FALSE else NA
      } else if (isTRUE(w)) {
        !is_group_col
      } else if (isFALSE(w)) {
        FALSE
      } else if (is.character(w)) {
        !is_group_col && cn %in% w
      } else {
        FALSE  # nocov - validated upstream
      }
    }

    # gp: tfl_colspec$gp (group cols only, already validated at construction)
    gp <- spec$gp

    list(col          = cn,
         label        = label,
         width        = width,   # unit / numeric / NULL; set to inches later
         align        = align,
         wrap         = wrap,
         gp           = gp,
         is_group_col = is_group_col)
  })
}

# ---------------------------------------------------------------------------
# compute_col_widths() — measure, relative, fixed, wrap, column groups
# ---------------------------------------------------------------------------

#' Compute final column widths and column groups
#'
#' @param overflow_action One of `"error"` (default) or `"warn"`. Controls how
#'   width-overflow conditions are reported. See [export_tfl_page()].
#' @param validate_overflow Logical (internal). When `FALSE`, skip the
#'   per-column / group-aware / total-width overflow checks. The second
#'   `cw_adj` pass in `.tfl_table_to_pagelist_default()` sets this to `FALSE`
#'   so the same overflow is not re-signalled on every pass.
#' @return A list with `$resolved_cols` (widths_in filled in) and
#'   `$col_groups` (list of integer vectors of column indices per group).
#' @keywords internal
compute_col_widths <- function(resolved_cols, data, content_width_in,
                               tbl, pg_width, pg_height, margins,
                               overflow_action   = c("error", "warn"),
                               validate_overflow = TRUE) {
  overflow_action <- match.arg(overflow_action)
  n_cols    <- length(resolved_cols)
  n_grp     <- length(tbl$group_vars)
  min_in    <- .width_in(tbl$min_col_width)
  cell_pad  <- tbl$cell_padding   # 4-element named unit (top/right/bottom/left)
  h_pad_in  <- .width_in(cell_pad[["right"]]) +
               .width_in(cell_pad[["left"]])
  na_str    <- tbl$na_string
  max_rows  <- tbl$max_measure_rows

  # --- Open scratch device for text width measurement ---
  # The device is closed immediately after measurement (before relative weight
  # resolution and wrapping) because .apply_col_wrapping() opens its own device.
  # on.exit ensures cleanup if the measurement loop errors.
  scratch_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(scratch_file, width = pg_width, height = pg_height)
  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)
  on.exit({
    grid::popViewport()                  # nocov
    grDevices::dev.off()                 # nocov
    unlink(scratch_file)                 # nocov
  }, add = TRUE)

  widths_in <- vapply(seq_len(n_cols), function(j) {
    cs <- resolved_cols[[j]]
    w  <- cs$width

    if (inherits(w, "unit")) {
      # Fixed unit width — apply floor
      max(min_in, .width_in(w))
    } else if (is.numeric(w) && !is.null(w)) {
      NA_real_  # relative weight — resolved in second pass
    } else {
      # NULL / missing — auto-size from content
      cell_gp <- .gp_with_lineheight(
        .resolve_table_cell_gp(tbl$gp, cs$is_group_col), tbl$line_height
      )
      strings <- .collect_col_strings(data[[cs$col]], cs$label, na_str, max_rows)
      w_max   <- .measure_max_string_width(strings, cell_gp)
      max(min_in, w_max + h_pad_in)
    }
  }, numeric(1L))

  # Measure half-width of a col_cont_msg label while the device is still open.
  # The label is rotated 90°, so its viewport "width" equals one character height.
  # Divided by 2 because the text is centred at x = 0 or x = 1 npc, placing
  # half its width inside the viewport.  Returned so the caller can decide
  # whether a second compute_col_widths() pass is needed.
  col_cont_label_half_w <- if (!is.null(tbl$col_cont_msg)) {
    cont_gp <- .gp_with_lineheight(
      .resolve_table_gp(tbl$gp, "continued"), tbl$line_height
    )
    .height_in(grid::grobHeight(grid::textGrob("M", gp = cont_gp))) / 2
  } else {
    0
  }

  # Close the scratch device now — must happen before .apply_col_wrapping()
  # opens its own device.  Clear the on.exit handler to avoid a double-close.
  grid::popViewport()
  grDevices::dev.off()
  unlink(scratch_file)
  on.exit(NULL)

  # --- Resolve relative weights ---
  rel_idx <- which(vapply(resolved_cols, function(cs) {
    is.numeric(cs$width) && !is.null(cs$width) && !inherits(cs$width, "unit")
  }, logical(1L)))

  if (length(rel_idx) > 0L) {
    fixed_total <- sum(widths_in[-rel_idx], na.rm = TRUE)
    avail_for_rel <- max(0, content_width_in - fixed_total)
    weights <- vapply(rel_idx, function(j) resolved_cols[[j]]$width, numeric(1L))
    weight_total <- sum(weights)
    widths_in[rel_idx] <- vapply(weights, function(w) {
      max(min_in, avail_for_rel * w / weight_total)
    }, numeric(1L))
  }

  # --- Resolve auto-detect wrap eligibility (cs$wrap == NA) ---
  # The "auto" mode marks data columns as NA in resolve_col_specs(); we
  # promote each NA to TRUE / FALSE here based on whether the column actually
  # contains a break character.  Skipping a column with no breakable text
  # avoids wasting a wrap pass on numeric / single-token columns where it
  # could not narrow the width anyway.
  breaks <- tbl$wrap_breaks %||% wrap_breaks_default()
  for (j in seq_len(n_cols)) {
    cs_j <- resolved_cols[[j]]
    if (is.logical(cs_j$wrap) && length(cs_j$wrap) == 1L && is.na(cs_j$wrap)) {
      strings <- .collect_col_strings(data[[cs_j$col]], cs_j$label,
                                      na_str, max_rows)
      resolved_cols[[j]]$wrap <- .column_has_breakable_text(strings, breaks)
    }
  }

  # --- Attempt word-wrap if total exceeds content width ---
  total_w <- sum(widths_in)

  if (total_w > content_width_in + 1e-6) {
    widths_in <- .compute_wrapped_widths(
      widths_in, resolved_cols, data, tbl, content_width_in,
      h_pad_in, min_in, pg_width, pg_height, margins
    )
    total_w <- sum(widths_in)
  }

  # --- Check feasibility ---
  errors <- character(0)

  if (!validate_overflow) {
    # Skip overflow validation entirely.  The caller (typically the second
    # cw_adj pass in .tfl_table_to_pagelist_default) is recomputing widths
    # for layout reasons after a prior pass already validated the same
    # configuration; re-signalling here would emit a duplicate warning.
    resolved_cols <- lapply(seq_len(n_cols), function(j) {
      cs <- resolved_cols[[j]]
      cs$width_in <- widths_in[[j]]
      cs
    })
    col_groups <- paginate_cols(widths_in, content_width_in, n_grp,
                                tbl$allow_col_split, tbl$balance_col_pages)
    return(list(resolved_cols         = resolved_cols,
                col_groups            = col_groups,
                col_cont_label_half_w = col_cont_label_half_w))
  }

  # Per-column / group-aware overflow check.  Group columns repeat on every
  # column-paginated page, so the available width for any single data column
  # is content_width_in - grp_w.  A group column itself must fit in the full
  # content width (grp_w == 0 if there are no group columns, in which case the
  # data-col rule reduces to `widths_in[j] > content_width_in`).
  grp_w <- if (n_grp > 0L) sum(widths_in[seq_len(n_grp)]) else 0
  for (j in seq_len(n_cols)) {
    cs <- resolved_cols[[j]]
    if (j <= n_grp) {
      # Group column j: must fit in content_width_in alone
      if (widths_in[[j]] > content_width_in + 1e-6) {
        errors <- .overflow_signal(
          sprintf(
            paste0("Group column '%s' width (%.3g in) exceeds available ",
                   "content width (%.3g in)"),
            cs$col, widths_in[[j]], content_width_in
          ),
          overflow_action, errors
        )
      }
    } else {
      # Data column j: must fit alongside the group columns on a single page.
      # Use a tiny tolerance and avoid double-reporting when n_grp == 0 and
      # the same overflow would also be caught by the (commented) total check.
      if (grp_w + widths_in[[j]] > content_width_in + 1e-6) {
        if (n_grp > 0L) {
          msg <- sprintf(
            paste0("Column '%s' (%.3g in) plus group columns (%.3g in) ",
                   "= %.3g in exceeds available content width (%.3g in); ",
                   "no column-paginated page can fit this column with the ",
                   "row headers"),
            cs$col, widths_in[[j]], grp_w,
            grp_w + widths_in[[j]], content_width_in
          )
        } else {
          msg <- sprintf(
            paste0("Column '%s' width (%.3g in) exceeds available content ",
                   "width (%.3g in)"),
            cs$col, widths_in[[j]], content_width_in
          )
        }
        errors <- .overflow_signal(msg, overflow_action, errors)
      }
    }
  }

  # Total-width check: only meaningful when allow_col_split = FALSE.  When
  # allow_col_split = TRUE, paginate_cols() handles the multi-page split and
  # this is not an overflow event.
  if (total_w > content_width_in + 1e-6 && !tbl$allow_col_split) {
    col_detail <- paste(vapply(seq_len(n_cols), function(j) {
      sprintf("  %s: %.3g in", resolved_cols[[j]]$col, widths_in[[j]])
    }, character(1L)), collapse = "\n")
    msg <- sprintf(paste0(
      "Total column width (%.3g in) exceeds available content width (%.3g in) ",
      "after wrapping.\nColumn widths:\n%s\n",
      "Set `allow_col_split = TRUE` to split columns across pages, ",
      "or reduce column widths / enable wrap_cols."
    ), total_w, content_width_in, col_detail)
    errors <- .overflow_signal(msg, overflow_action, errors)
  }

  if (length(errors) > 0L) {
    rlang::abort(paste(errors, collapse = "\n"))
  }

  # --- Store final widths in resolved_cols ---
  resolved_cols <- lapply(seq_len(n_cols), function(j) {
    cs <- resolved_cols[[j]]
    cs$width_in <- widths_in[[j]]
    cs
  })

  # --- Determine column groups ---
  col_groups <- paginate_cols(widths_in, content_width_in, n_grp,
                              tbl$allow_col_split, tbl$balance_col_pages)

  list(resolved_cols            = resolved_cols,
       col_groups               = col_groups,
       col_cont_label_half_w    = col_cont_label_half_w)
}

# ---------------------------------------------------------------------------
# paginate_cols() — split data column indices into groups
# ---------------------------------------------------------------------------

#' Split data columns into groups that fit within content_width_in
#'
#' Group columns (first n_group_cols) are always included in every group.
#' Data columns are greedily packed left-to-right.  When `balance_col_pages`
#' is `TRUE` and the greedy pass produces more than one page, the data columns
#' are redistributed so that each page receives approximately the same number
#' of columns (while still verifying that each balanced group fits within the
#' available width).
#'
#' @return List of integer vectors (column indices into resolved_cols).
#' @keywords internal
paginate_cols <- function(widths_in, content_width_in, n_group_cols,
                          allow_col_split, balance_col_pages = FALSE) {
  n_cols    <- length(widths_in)
  n_data    <- n_cols - n_group_cols
  grp_w     <- if (n_group_cols > 0L) sum(widths_in[seq_len(n_group_cols)]) else 0
  avail_w   <- content_width_in - grp_w
  data_idx  <- seq_len(n_data) + n_group_cols  # 1-based into widths_in

  if (n_data == 0L) return(list(seq_len(n_group_cols)))

  # --- Greedy left-to-right pagination ---
  groups       <- list()
  current_idxs <- integer(0L)
  current_w    <- 0

  for (j in data_idx) {
    col_w <- widths_in[[j]]
    if (current_w + col_w > avail_w + 1e-6 && length(current_idxs) > 0L) {
      groups       <- c(groups, list(c(seq_len(n_group_cols), current_idxs)))
      current_idxs <- j
      current_w    <- col_w
    } else {
      current_idxs <- c(current_idxs, j)
      current_w    <- current_w + col_w
    }
  }
  if (length(current_idxs) > 0L) {
    groups <- c(groups, list(c(seq_len(n_group_cols), current_idxs)))
  }

  # --- Optional: balance columns evenly across pages ---
  if (balance_col_pages && length(groups) > 1L) {
    p      <- length(groups)
    base   <- n_data %/% p
    extra  <- n_data %%  p
    # Sizes: first 'extra' pages get (base+1), the rest get base
    sizes  <- c(rep(base + 1L, extra), rep(base, p - extra))

    # Build candidate balanced groups from those sizes
    balanced <- vector("list", p)
    offset   <- 0L
    ok       <- TRUE
    for (k in seq_len(p)) {
      idxs <- data_idx[offset + seq_len(sizes[[k]])]
      offset <- offset + sizes[[k]]
      page_w <- sum(widths_in[idxs])
      if (page_w > avail_w + 1e-6) { ok <- FALSE; break }
      balanced[[k]] <- c(seq_len(n_group_cols), idxs)
    }
    if (ok) groups <- balanced
    # If any page overflows, fall back silently to the greedy result
  }

  groups
}
