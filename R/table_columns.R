# table_columns.R — Column specification, width computation, and column pagination
#
# Functions:
#   resolve_col_specs()      — merge tfl_colspec + flat tfl_table() args per column
#   compute_col_widths()     — auto-size, relative, fixed, wrap; returns widths + groups
#   .apply_col_wrapping()    — iteratively narrow wrap-eligible columns to fit
#   paginate_cols()          — split column indices into per-page groups

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

    # Wrap: tfl_colspec > wrap_cols flat arg
    wrap <- if (!is.null(spec$wrap)) {
      spec$wrap
    } else {
      w <- tbl$wrap_cols
      if (isTRUE(w)) !is_group_col  # TRUE = all data cols eligible
      else if (isFALSE(w)) FALSE
      else cn %in% w
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
#' @return A list with `$resolved_cols` (widths_in filled in) and
#'   `$col_groups` (list of integer vectors of column indices per group).
#' @keywords internal
compute_col_widths <- function(resolved_cols, data, content_width_in,
                               tbl, pg_width, pg_height, margins) {
  n_cols    <- length(resolved_cols)
  n_grp     <- length(tbl$group_vars)
  min_in    <- grid::convertWidth(tbl$min_col_width, "inches", valueOnly = TRUE)
  cell_pad  <- tbl$cell_padding   # 4-element named unit (top/right/bottom/left)
  h_pad_in  <- grid::convertWidth(cell_pad[["right"]], "inches", valueOnly = TRUE) +
               grid::convertWidth(cell_pad[["left"]],  "inches", valueOnly = TRUE)
  na_str    <- tbl$na_string
  max_rows  <- tbl$max_measure_rows

  # --- Open scratch device for text width measurement ---
  # The device is closed immediately after measurement (before relative weight

  # resolution and wrapping) because .apply_col_wrapping() opens its own device.
  # on.exit ensures cleanup if the measurement loop errors.
  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  outer_vp <- .make_outer_vp(margins, pg_width, pg_height)
  grid::pushViewport(outer_vp)
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
  }, add = TRUE)

  widths_in <- vapply(seq_len(n_cols), function(j) {
    cs <- resolved_cols[[j]]
    w  <- cs$width

    if (inherits(w, "unit")) {
      # Fixed unit width — apply floor
      max(min_in, grid::convertWidth(w, "inches", valueOnly = TRUE))
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

  # Close the scratch device now — must happen before .apply_col_wrapping()
  # opens its own device.  Clear the on.exit handler to avoid a double-close.
  grid::popViewport()
  grDevices::dev.off()
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

  # --- Attempt word-wrap if total exceeds content width ---
  total_w <- sum(widths_in)

  if (total_w > content_width_in + 1e-6) {
    widths_in <- .apply_col_wrapping(
      widths_in, resolved_cols, data, tbl, content_width_in,
      min_in, h_pad_in, na_str, max_rows, pg_width, pg_height, margins
    )
    total_w <- sum(widths_in)
  }

  # --- Check feasibility ---
  if (total_w > content_width_in + 1e-6) {
    if (!tbl$allow_col_split) {
      rlang::abort(sprintf(paste0(
        "Total column width (%.3g in) exceeds available content width (%.3g in) ",
        "after wrapping. Set `allow_col_split = TRUE` to split columns across pages, ",
        "or reduce column widths / enable wrap_cols."
      ), total_w, content_width_in))
    }
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

  list(resolved_cols = resolved_cols, col_groups = col_groups)
}

# ---------------------------------------------------------------------------
# .apply_col_wrapping()
# ---------------------------------------------------------------------------

#' Iteratively narrow wrap-eligible columns until total fits or all at min
#' @keywords internal
.apply_col_wrapping <- function(widths_in, resolved_cols, data, tbl,
                                content_width_in, min_in, h_pad_in,
                                na_str, max_rows, pg_width, pg_height, margins) {
  n <- length(widths_in)
  wrap_eligible <- vapply(resolved_cols, `[[`, logical(1L), "wrap")

  if (!any(wrap_eligible)) return(widths_in)

  grDevices::pdf(NULL, width = pg_width, height = pg_height)
  outer_vp <- .make_outer_vp(margins, pg_width, pg_height)
  grid::pushViewport(outer_vp)
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
  }, add = TRUE)

  # Repeat reduction passes until fits or no more room
  for (pass in seq_len(100L)) {
    total <- sum(widths_in)
    if (total <= content_width_in + 1e-6) break

    excess  <- total - content_width_in
    # Find widest eligible column that is still above min
    eligible_above_min <- which(wrap_eligible & widths_in > min_in + 1e-6)
    if (length(eligible_above_min) == 0L) break

    target_j <- eligible_above_min[which.max(widths_in[eligible_above_min])]

    # Try wrapping text in that column to a narrower target
    new_w <- max(min_in, widths_in[target_j] - excess)
    # Re-measure: what is the minimum content width needed after wrapping?
    cs      <- resolved_cols[[target_j]]
    cell_gp <- .resolve_table_cell_gp(tbl$gp, cs$is_group_col)
    strings <- .collect_col_strings(data[[cs$col]], cs$label, na_str, max_rows)
    # Use new_w as the wrap target: accept it (word-wrap will reflow at draw time)
    widths_in[target_j] <- new_w
  }

  widths_in
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
