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
                               validate_overflow = TRUE,
                               floor_overrides   = NULL) {
  overflow_action <- match.arg(overflow_action)
  strategy <- tbl$col_split_strategy %||% "balanced"

  # Shared setup: compute natural widths, resolve relative weights,
  # auto-detect wrap eligibility, and measure col_cont_label_half_w.
  setup <- .resolve_natural_widths(
    resolved_cols, data, content_width_in, tbl, pg_width, pg_height, margins
  )

  # Dispatch.  Each strategy returns list(resolved_cols, col_groups).
  if (identical(strategy, "wrap_first")) {
    res <- .compute_col_widths_wrap_first(
      widths_natural    = setup$widths_natural,
      resolved_cols     = setup$resolved_cols,
      data              = data,
      content_width_in  = content_width_in,
      tbl               = tbl,
      pg_width          = pg_width,
      pg_height         = pg_height,
      margins           = margins,
      overflow_action   = overflow_action,
      validate_overflow = validate_overflow,
      h_pad_in          = setup$h_pad_in,
      min_in            = setup$min_in,
      n_grp             = setup$n_grp,
      breaks            = setup$breaks
    )
  } else {
    res <- .compute_col_widths_balanced(
      widths_natural    = setup$widths_natural,
      resolved_cols     = setup$resolved_cols,
      data              = data,
      content_width_in  = content_width_in,
      tbl               = tbl,
      pg_width          = pg_width,
      pg_height         = pg_height,
      margins           = margins,
      overflow_action   = overflow_action,
      validate_overflow = validate_overflow,
      h_pad_in          = setup$h_pad_in,
      min_in            = setup$min_in,
      n_grp             = setup$n_grp,
      breaks            = setup$breaks,
      floor_overrides   = floor_overrides
    )
  }

  res$col_cont_label_half_w <- setup$col_cont_label_half_w
  res
}

# ---------------------------------------------------------------------------
# .resolve_natural_widths() - shared setup (Passes 1, 2, 3)
# ---------------------------------------------------------------------------

# Computes per-column natural widths, resolves relative weights, and
# auto-detects wrap eligibility.  Returns the per-column natural width
# vector, the updated resolved_cols (with wrap eligibility resolved),
# the measured `col_cont_label_half_w` for later layout decisions, and a
# handful of derived scalars (`h_pad_in`, `min_in`, `n_grp`, `breaks`)
# the strategy functions need.
#
# The scratch device used for text measurement is opened, used, and
# closed inside this function so neither strategy has to manage it.
.resolve_natural_widths <- function(resolved_cols, data, content_width_in,
                                     tbl, pg_width, pg_height, margins) {
  n_cols    <- length(resolved_cols)
  n_grp     <- length(tbl$group_vars)
  min_in    <- .width_in(tbl$min_col_width)
  cell_pad  <- tbl$cell_padding
  h_pad_in  <- .width_in(cell_pad[["right"]]) +
               .width_in(cell_pad[["left"]])
  na_str    <- tbl$na_string
  max_rows  <- tbl$max_measure_rows

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
      max(min_in, .width_in(w))
    } else if (is.numeric(w) && !is.null(w)) {
      NA_real_  # relative weight - resolved below
    } else {
      cell_gp <- .gp_with_lineheight(
        .resolve_table_cell_gp(tbl$gp, cs$is_group_col), tbl$line_height
      )
      hdr_gp <- .gp_with_lineheight(
        .resolve_table_gp(tbl$gp, "header_row"), tbl$line_height
      )
      parts  <- .split_col_strings(data[[cs$col]], cs$label, na_str, max_rows)
      w_data <- .measure_max_string_width(parts$data, cell_gp)
      w_hdr  <- .measure_max_string_width(parts$header, hdr_gp)
      max(min_in, max(w_data, w_hdr) + h_pad_in)
    }
  }, numeric(1L))

  col_cont_label_half_w <- if (!is.null(tbl$col_cont_msg)) {
    cont_gp <- .gp_with_lineheight(
      .resolve_table_gp(tbl$gp, "continued"), tbl$line_height
    )
    .height_in(grid::grobHeight(grid::textGrob("M", gp = cont_gp))) / 2
  } else {
    0
  }

  # Close the scratch device now so strategy functions can open their own
  # without nested-device complications.
  grid::popViewport()
  grDevices::dev.off()
  unlink(scratch_file)
  on.exit(NULL)

  # Resolve relative weights.
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

  # Auto-detect wrap eligibility (cs$wrap == NA - the "auto" mode marks
  # data columns as NA in resolve_col_specs(); promote each NA to TRUE
  # / FALSE based on whether the column contains a break character).
  breaks <- tbl$wrap_breaks %||% wrap_breaks_default()
  for (j in seq_len(n_cols)) {
    cs_j <- resolved_cols[[j]]
    if (is.logical(cs_j$wrap) && length(cs_j$wrap) == 1L && is.na(cs_j$wrap)) {
      strings <- .collect_col_strings(data[[cs_j$col]], cs_j$label,
                                      na_str, max_rows)
      resolved_cols[[j]]$wrap <- .column_has_breakable_text(strings, breaks)
    }
  }

  list(
    widths_natural        = widths_in,
    resolved_cols         = resolved_cols,
    col_cont_label_half_w = col_cont_label_half_w,
    h_pad_in              = h_pad_in,
    min_in                = min_in,
    n_grp                 = n_grp,
    breaks                = breaks
  )
}

# ---------------------------------------------------------------------------
# .compute_col_widths_wrap_first() - legacy pre-issue-35 strategy
# ---------------------------------------------------------------------------

# Whole-table water-fill first, then page-split using the post-wrap widths.
# This is the strategy that shipped with issue #28; preserved verbatim so
# the new "balanced" strategy can be compared empirically against it.
.compute_col_widths_wrap_first <- function(widths_natural, resolved_cols, data,
                                            content_width_in, tbl,
                                            pg_width, pg_height, margins,
                                            overflow_action, validate_overflow,
                                            h_pad_in, min_in, n_grp, breaks) {
  n_cols    <- length(resolved_cols)
  na_str    <- tbl$na_string
  max_rows  <- tbl$max_measure_rows
  widths_in <- widths_natural

  # Word-wrap if total exceeds content width.
  total_w <- sum(widths_in)
  if (total_w > content_width_in + 1e-6) {
    widths_in <- .compute_wrapped_widths(
      widths_in, resolved_cols, data, tbl, content_width_in,
      h_pad_in, min_in, pg_width, pg_height, margins
    )
    total_w <- sum(widths_in)
  }

  # Optional whole-table height-balance.
  if (identical(tbl$wrap_balance, "height")) {
    widths_in <- .height_balance_widths(
      widths_in, resolved_cols, data, tbl,
      h_pad_in = h_pad_in, na_str = na_str, max_rows = max_rows,
      breaks = breaks, pg_width = pg_width, pg_height = pg_height,
      margins = margins
    )
    total_w <- sum(widths_in)
  }

  errors <- character(0)

  if (!validate_overflow) {
    resolved_cols <- lapply(seq_len(n_cols), function(j) {
      cs <- resolved_cols[[j]]
      cs$width_in <- widths_in[[j]]
      cs
    })
    col_groups <- paginate_cols(widths_in, content_width_in, n_grp,
                                tbl$allow_col_split, tbl$balance_col_pages)
    return(list(resolved_cols = resolved_cols, col_groups = col_groups))
  }

  errors <- .check_col_overflow_per_col(widths_in, resolved_cols, n_grp,
                                         content_width_in, overflow_action,
                                         errors)
  if (total_w > content_width_in + 1e-6 && !tbl$allow_col_split) {
    errors <- .check_total_width_overflow(widths_in, resolved_cols,
                                           content_width_in, overflow_action,
                                           errors, total_w)
  }
  if (length(errors) > 0L) {
    rlang::abort(paste(errors, collapse = "\n"))
  }

  resolved_cols <- lapply(seq_len(n_cols), function(j) {
    cs <- resolved_cols[[j]]
    cs$width_in <- widths_in[[j]]
    cs
  })
  col_groups <- paginate_cols(widths_in, content_width_in, n_grp,
                              tbl$allow_col_split, tbl$balance_col_pages)

  list(resolved_cols = resolved_cols, col_groups = col_groups)
}

# ---------------------------------------------------------------------------
# .compute_col_widths_balanced() - issue #35 strategy
# ---------------------------------------------------------------------------

# Decision tree from issue #35:
#  A. If sum(natural) <= content_width  -> use natural; single page.
#  B. Elif sum(min)    <= content_width  -> single page; water-fill from
#     natural down to fit.  (Mathematically equivalent to today's whole-
#     table water-fill when there's no page split.)
#  C. Else: page-split using MIN widths for capacity planning.  For each
#     resulting page, water-fill from natural down to that page's slack,
#     with group columns pinned at their MIN width so data columns receive
#     the most per-page slack.  Reconcile per-page widths into one
#     per-column vector (group columns get the MIN across pages; data
#     columns each appear on one page only).
#
# `floor_overrides` is a named numeric vector (col -> min width override
# in inches).  When a column's name is in the override map, its computed
# minimum is `max(computed_min, override)`.  Used by the row-overflow
# retry loop in `.tfl_table_to_pagelist_default()` to widen a column whose
# cell content forced a too-tall row.
.compute_col_widths_balanced <- function(widths_natural, resolved_cols, data,
                                          content_width_in, tbl,
                                          pg_width, pg_height, margins,
                                          overflow_action, validate_overflow,
                                          h_pad_in, min_in, n_grp, breaks,
                                          floor_overrides) {
  n_cols     <- length(resolved_cols)
  na_str     <- tbl$na_string
  max_rows   <- tbl$max_measure_rows
  eps        <- 1e-6

  wrap_eligible <- vapply(resolved_cols, `[[`, logical(1L), "wrap")

  # Compute per-column minimum widths.  For non-wrap-eligible cols the
  # minimum is the natural width (they can't shrink).  For wrap-eligible
  # cols it's the longest-token floor.
  widths_min <- .compute_col_min_widths(
    widths_natural    = widths_natural,
    resolved_cols     = resolved_cols,
    data              = data,
    tbl               = tbl,
    h_pad_in          = h_pad_in,
    min_in            = min_in,
    pg_width          = pg_width,
    pg_height         = pg_height,
    margins           = margins
  )

  # Apply floor overrides from the row-overflow retry loop, if any.
  # An override raises both widths_min AND widths_natural: it represents
  # "the renderer told us this column needs to be at least N inches wide
  # for its content to fit on a page", which is a hard lower bound the
  # decision tree must honour even on the Case-A (no-wrap-needed) path
  # where widths_natural would otherwise be used as-is.
  if (length(floor_overrides) > 0L) {
    for (col_name in names(floor_overrides)) {
      j <- match(col_name,
                 vapply(resolved_cols, `[[`, character(1L), "col"))
      if (!is.na(j)) {
        bumped_floor       <- max(widths_min[[j]],
                                  unname(floor_overrides[[col_name]]))
        widths_min[[j]]    <- bumped_floor
        widths_natural[[j]] <- max(widths_natural[[j]], bumped_floor)
      }
    }
  }

  total_natural <- sum(widths_natural)
  total_min     <- sum(widths_min)

  if (total_natural <= content_width_in + eps) {
    # Case A: everything fits at natural width.
    widths_in  <- widths_natural
    col_groups <- list(seq_len(n_cols))
  } else if (total_min <= content_width_in + eps) {
    # Case B: everything fits if we wrap.  Single page.
    widths_in  <- .water_fill_to_budget(
      widths_in     = widths_natural,
      widths_min    = widths_min,
      wrap_eligible = wrap_eligible,
      budget_in     = content_width_in
    )
    col_groups <- list(seq_len(n_cols))
  } else {
    # Case C: page-split using min widths for capacity planning.  Group
    # columns are pinned at their min width on every page; data columns
    # on each page water-fill from natural down to that page's slack.
    col_groups <- paginate_cols(
      widths_min, content_width_in, n_grp,
      tbl$allow_col_split, tbl$balance_col_pages
    )

    per_page_widths <- vector("list", length(col_groups))
    for (g in seq_along(col_groups)) {
      page_idx <- col_groups[[g]]
      # Starting widths: group cols at min, data cols at natural.
      page_w <- numeric(length(page_idx))
      for (k in seq_along(page_idx)) {
        j <- page_idx[[k]]
        if (j <= n_grp) {
          page_w[[k]] <- widths_min[[j]]
        } else {
          page_w[[k]] <- widths_natural[[j]]
        }
      }
      # wrap_eligible for water-fill: only DATA cols may shrink further.
      # Group cols are pinned at min and excluded from active set.
      page_elig <- wrap_eligible[page_idx]
      for (k in seq_along(page_idx)) {
        if (page_idx[[k]] <= n_grp) page_elig[[k]] <- FALSE
      }
      per_page_widths[[g]] <- .water_fill_to_budget(
        widths_in     = page_w,
        widths_min    = widths_min[page_idx],
        wrap_eligible = page_elig,
        budget_in     = content_width_in
      )
    }
    widths_in <- .reconcile_page_widths(per_page_widths, col_groups,
                                         n_group_cols = n_grp,
                                         n_cols       = n_cols)
  }

  # Optional per-page height-balance (opt-in via wrap_balance = "height").
  if (identical(tbl$wrap_balance, "height") && length(col_groups) >= 1L) {
    widths_in <- .apply_per_page_height_balance(
      widths_in       = widths_in,
      col_groups      = col_groups,
      resolved_cols   = resolved_cols,
      data            = data,
      tbl             = tbl,
      h_pad_in        = h_pad_in,
      na_str          = na_str,
      max_rows        = max_rows,
      breaks          = breaks,
      pg_width        = pg_width,
      pg_height       = pg_height,
      margins         = margins,
      n_grp           = n_grp
    )
  }

  errors <- character(0)

  if (!validate_overflow) {
    resolved_cols <- lapply(seq_len(n_cols), function(j) {
      cs <- resolved_cols[[j]]
      cs$width_in <- widths_in[[j]]
      cs$width_natural_in <- widths_natural[[j]]
      cs$width_min_in     <- widths_min[[j]]
      cs
    })
    return(list(resolved_cols = resolved_cols, col_groups = col_groups))
  }

  errors <- .check_col_overflow_per_col(widths_in, resolved_cols, n_grp,
                                         content_width_in, overflow_action,
                                         errors)
  if (sum(widths_in) > content_width_in + eps && !tbl$allow_col_split &&
      length(col_groups) > 1L) {
    errors <- .check_total_width_overflow(widths_in, resolved_cols,
                                           content_width_in, overflow_action,
                                           errors, sum(widths_in))
  }
  if (length(errors) > 0L) {
    rlang::abort(paste(errors, collapse = "\n"))
  }

  resolved_cols <- lapply(seq_len(n_cols), function(j) {
    cs <- resolved_cols[[j]]
    cs$width_in <- widths_in[[j]]
    cs$width_natural_in <- widths_natural[[j]]
    cs$width_min_in     <- widths_min[[j]]
    cs
  })

  list(resolved_cols = resolved_cols, col_groups = col_groups)
}

# Per-page height-balance helper used by .compute_col_widths_balanced().
# Calls .height_balance_widths() once per page-column-split page with the
# page's column subset; reconciles results back into a flat per-column
# width vector.  Non-group columns appear on exactly one page so their
# height-balanced width is the result.  Group columns appear on every
# page; their width is kept at the input value (since group cols don't
# participate in height-balance anyway).
.apply_per_page_height_balance <- function(widths_in, col_groups,
                                            resolved_cols, data, tbl,
                                            h_pad_in, na_str, max_rows,
                                            breaks, pg_width, pg_height,
                                            margins, n_grp) {
  widths_out <- widths_in
  for (g in seq_along(col_groups)) {
    page_idx <- col_groups[[g]]
    page_cols <- resolved_cols[page_idx]
    page_widths <- widths_in[page_idx]
    page_data <- data[, vapply(page_cols, `[[`, character(1L), "col"),
                      drop = FALSE]
    balanced <- .height_balance_widths(
      widths_in     = page_widths,
      resolved_cols = page_cols,
      data          = page_data,
      tbl           = tbl,
      h_pad_in      = h_pad_in,
      na_str        = na_str,
      max_rows      = max_rows,
      breaks        = breaks,
      pg_width      = pg_width,
      pg_height     = pg_height,
      margins       = margins
    )
    # Only non-group columns are updated; group columns stay at their
    # input width.
    for (k in seq_along(page_idx)) {
      j <- page_idx[[k]]
      if (j > n_grp) {
        widths_out[[j]] <- balanced[[k]]
      }
    }
  }
  widths_out
}

# ---------------------------------------------------------------------------
# Shared overflow-check helpers
# ---------------------------------------------------------------------------

# Per-column overflow validation.  Group columns must fit content_width
# alone; data columns must fit alongside the group columns on a single
# page (since group columns repeat on every column-paginated page).
.check_col_overflow_per_col <- function(widths_in, resolved_cols, n_grp,
                                         content_width_in, overflow_action,
                                         errors) {
  n_cols <- length(resolved_cols)
  grp_w  <- if (n_grp > 0L) sum(widths_in[seq_len(n_grp)]) else 0
  for (j in seq_len(n_cols)) {
    cs <- resolved_cols[[j]]
    if (j <= n_grp) {
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
  errors
}

# Total-width overflow check.  Only meaningful when allow_col_split = FALSE.
.check_total_width_overflow <- function(widths_in, resolved_cols,
                                         content_width_in, overflow_action,
                                         errors, total_w) {
  n_cols <- length(resolved_cols)
  col_detail <- paste(vapply(seq_len(n_cols), function(j) {
    sprintf("  %s: %.3g in", resolved_cols[[j]]$col, widths_in[[j]])
  }, character(1L)), collapse = "\n")
  msg <- sprintf(paste0(
    "Total column width (%.3g in) exceeds available content width (%.3g in) ",
    "after wrapping.\nColumn widths:\n%s\n",
    "Set `allow_col_split = TRUE` to split columns across pages, ",
    "or reduce column widths / enable wrap_cols."
  ), total_w, content_width_in, col_detail)
  .overflow_signal(msg, overflow_action, errors)
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
