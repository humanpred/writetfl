# sub_tfl.R — Sub-table support for tfl_table and ggtibble.
#
# When `sub_tfl` is set on a tfl_table (or export_tfl.ggtibble), the data is
# split into one sub-table per unique combination of values in the named
# columns.  The values are removed from the rendered body and appended to the
# caption as "label: value; label: value".

# ---------------------------------------------------------------------------
# Top-level helpers (no nested function definitions)
# ---------------------------------------------------------------------------

# Ordered unique values of a single column. Factor columns drive their level
# order (filtered to present values); other columns use first-appearance.
#' @keywords internal
.ordered_unique_values <- function(col_data) {
  v_nona <- col_data[!is.na(col_data)]
  if (is.factor(col_data)) {
    lv <- levels(col_data)
    lv[lv %in% as.character(v_nona)]
  } else {
    unique(v_nona)
  }
}

# Wrap a single column's value as a one-element named list — the seed for the
# Cartesian-product accumulator in .compute_sub_tfl_groups().
#' @keywords internal
.named_one_value <- function(value, name) {
  stats::setNames(list(value), name)
}

# Logical predicate used by .strip_sub_tfl_cols() to filter colspec entries.
#' @keywords internal
.colspec_not_in <- function(cs, drop) {
  !cs$col %in% drop
}

# Build a single "label: value" pair for one sub_tfl column.
#' @keywords internal
.format_sub_tfl_pair <- function(col, tbl, values) {
  label <- .resolve_col_label(tbl, col)
  paste(label, format(values[[col]]), sep = tbl$sub_tfl_sep)
}

# Build a single "col: value" pair for ggtibble (raw column names, no colspec).
#' @keywords internal
.format_ggtibble_sub_tfl_pair <- function(col, x, i, sep) {
  paste(col, format(x[[col]][[i]]), sep = sep)
}

# ---------------------------------------------------------------------------
# .compute_sub_tfl_groups()
# ---------------------------------------------------------------------------

# Returns an ordered list of sub-group specs:
#   list(list(values = named-list, row_idx = integer), ...)
# Order: factor columns drive their level order; character/numeric columns use
# first-appearance order. sub_tfl[1] varies outermost (slowest).
#' @keywords internal
.compute_sub_tfl_groups <- function(data, sub_tfl) {
  ord_vals <- lapply(data[sub_tfl], .ordered_unique_values)
  names(ord_vals) <- sub_tfl

  # Build combos with sub_tfl[1] outermost.
  combos <- lapply(ord_vals[[1L]], .named_one_value, name = sub_tfl[[1L]])
  for (k in seq_along(sub_tfl)[-1L]) {
    new_combos <- list()
    for (rc in combos) {
      for (v in ord_vals[[k]]) {
        rc_new <- rc
        rc_new[[sub_tfl[[k]]]] <- v
        new_combos[[length(new_combos) + 1L]] <- rc_new
      }
    }
    combos <- new_combos
  }

  # For each combo, find row indices in `data`. Skip combinations that are
  # not present in any row (Cartesian product may produce them).
  groups <- list()
  for (combo in combos) {
    matches <- rep(TRUE, nrow(data))
    for (col in sub_tfl) {
      v      <- data[[col]]
      target <- combo[[col]]
      m      <- v == target
      m[is.na(m)] <- FALSE
      matches <- matches & m
    }
    idx <- which(matches)
    if (length(idx) > 0L) {
      groups[[length(groups) + 1L]] <- list(values = combo, row_idx = idx)
    }
  }
  groups
}

# ---------------------------------------------------------------------------
# .resolve_col_label() — single source of truth for label fallback
# ---------------------------------------------------------------------------

# Priority: tfl_colspec$label > tbl$col_labels[col] > col itself.
#' @keywords internal
.resolve_col_label <- function(tbl, col_name) {
  if (!is.null(tbl$cols)) {
    for (cs in tbl$cols) {
      if (identical(cs$col, col_name) && !is.null(cs$label)) {
        return(cs$label)
      }
    }
  }
  flat <- .nlookup(tbl$col_labels, col_name)
  if (!is.null(flat)) return(flat)
  col_name
}

# ---------------------------------------------------------------------------
# .format_sub_tfl_caption()
# ---------------------------------------------------------------------------

# Build the per-page caption suffix from a named list of values.
#' @keywords internal
.format_sub_tfl_caption <- function(tbl, values) {
  pairs <- vapply(names(values), .format_sub_tfl_pair,
                  character(1L), tbl = tbl, values = values)
  paste(pairs, collapse = tbl$sub_tfl_collapse)
}

# ---------------------------------------------------------------------------
# .apply_sub_tfl_caption()
# ---------------------------------------------------------------------------

# Combine a base caption with the sub_tfl suffix using prefix rules.
# Returns the suffix alone when base is NULL.
#' @keywords internal
.apply_sub_tfl_caption <- function(base, suffix, prefix) {
  if (is.null(base)) return(suffix)
  paste0(base, prefix, suffix)
}

# ---------------------------------------------------------------------------
# .strip_sub_tfl_cols()
# ---------------------------------------------------------------------------

# Remove sub_tfl entries from cols / col_widths / col_labels / col_align /
# wrap_cols. The caller is responsible for filtering tbl$data and updating
# tbl$group_vars.
#' @keywords internal
.strip_sub_tfl_cols <- function(tbl) {
  drop <- tbl$sub_tfl
  if (!is.null(tbl$cols)) {
    keep <- vapply(tbl$cols, .colspec_not_in, logical(1L), drop = drop)
    tbl$cols <- tbl$cols[keep]
    if (length(tbl$cols) == 0L) tbl$cols <- NULL
  }
  for (fld in c("col_widths", "col_labels", "col_align")) {
    v <- tbl[[fld]]
    if (!is.null(v) && !is.null(names(v))) {
      tbl[[fld]] <- v[!names(v) %in% drop]
      if (length(tbl[[fld]]) == 0L) tbl[[fld]] <- NULL
    }
  }
  if (is.character(tbl$wrap_cols)) {
    tbl$wrap_cols <- setdiff(tbl$wrap_cols, drop)
  }
  tbl
}
