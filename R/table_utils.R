# table_utils.R — Internal helpers shared across table_pagelist, table_columns,
#                 table_rows, and table_draw.
#
# Functions:
#   .make_outer_vp()              — construct the margins viewport
#   .measure_header_row_height()  — height of the column header row
#   .measure_cont_row_height()    — height of a continuation-marker row
#   .gp_with_lineheight()         — inject lineheight into a gpar (respects overrides)
#   .compute_group_starts()       — row indices where a new group begins
#   .compute_group_sizes()        — number of rows per group
#   .collect_col_strings()        — unique strings for a column (header + data)
#   .fmt_cell()                   — format a single cell value (NA → na_string)
#   .fmt_cell_vec()               — vectorised version of .fmt_cell()
#   .measure_max_string_width()   — max rendered text width in inches
#   .resolve_table_gp()           — gpar for a named table section
#   .resolve_table_cell_gp()      — gpar for a data or group cell
#   .default_align()              — type-based default alignment
#   .wrap_text()                  — greedy word-wrap to a width in inches

# ---------------------------------------------------------------------------
# Viewport helpers
# ---------------------------------------------------------------------------

# Build outer_vp — shared by export_tfl_page() and table_* measurement code.
# Uses unit arithmetic so that margins in any unit (inches, lines, mm, etc.)
# are resolved correctly against the current device.
.make_outer_vp <- function(margins) {
  mt <- margins[1L]; mr <- margins[2L]; mb <- margins[3L]; ml <- margins[4L]
  grid::viewport(
    x      = ml,
    y      = mb,
    width  = grid::unit(1, "npc") - ml - mr,
    height = grid::unit(1, "npc") - mt - mb,
    just   = c("left", "bottom"),
    name   = "outer_vp"
  )
}

# ---------------------------------------------------------------------------
# Row height measurement helpers
# ---------------------------------------------------------------------------

# Measure column header row height (max across all column labels).
#
# When `breaks` is non-NULL and a column is wrap-eligible (`cs$wrap == TRUE`)
# with a resolved width, the label is run through .wrap_label_for_width()
# before measurement so headers get the same auto-line-breaking treatment as
# cell content.
#
# `wrap_extra_pad_in` is an inches scalar of extra height added at the
# bottom of any column whose (post-wrap) header is multi-line, so the gap
# between the header row and the first data row is more obvious.
.measure_header_row_height <- function(resolved_cols, gp_tbl, cell_padding,
                                       line_height, breaks = NULL,
                                       wrap_extra_pad_in = 0,
                                       cache = NULL) {
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  h_lft_in <- .width_in(cell_padding[["left"]])
  h_rgt_in <- .width_in(cell_padding[["right"]])
  hdr_gp   <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"),
                                   line_height)
  gp_key   <- paste0("header_row_lh", line_height)

  max(vapply(resolved_cols, function(cs) {
    label <- cs$label
    if (!is.null(breaks) && isTRUE(cs$wrap) && !is.null(cs$width_in)) {
      label <- .wrap_label_for_width(label, cs$width_in,
                                      h_lft_in + h_rgt_in, hdr_gp, breaks)
    }
    nlines <- max(1L, length(strsplit(label, "\n", fixed = TRUE)[[1L]]))
    h_grob <- .measure_text_dims_in(label, hdr_gp, gp_key, cache)$h
    h_line <- nlines * .height_in(grid::stringHeight("M"))
    extra  <- if (nlines > 1L) wrap_extra_pad_in else 0
    max(h_grob, h_line) + extra
  }, numeric(1L))) + v_pad_in
}

# Wrap a spanning-header cell to the width of the columns beneath it (span
# width minus horizontal padding).  Shared by the header-block measurement
# and drawing paths so their line counts and heights agree.
.wrap_header_cell <- function(text, span_width_in, h_pad_in, gp, breaks) {
  .wrap_label_for_width(text, span_width_in, h_pad_in, gp, breaks)
}

# Measure the multi-row column-header block.
#
# Returns list(row_heights = numeric(R), total = sum(row_heights)).  Row `r`'s
# height is the max over that row's non-empty span cells of the wrapped cell
# height (each cell wrapped to the width of the columns beneath it) plus
# vertical padding, with `wrap_extra_pad_in` added for multi-line cells.
#
# When `spans` is trivial (R == 1) this delegates to the single-row
# `.measure_header_row_height()` so non-spanning tables measure byte-identically.
# Must be called while a viewport with the header font context is active; uses
# the resolved column widths (`cs$width_in`) to size span cells.
.measure_header_block <- function(resolved_cols, spans, gp_tbl, cell_padding,
                                  line_height, breaks = NULL,
                                  wrap_extra_pad_in = 0, cache = NULL) {
  if (is.null(spans) || spans$R <= 1L) {
    h <- .measure_header_row_height(resolved_cols, gp_tbl, cell_padding,
                                    line_height, breaks = breaks,
                                    wrap_extra_pad_in = wrap_extra_pad_in,
                                    cache = cache)
    return(list(row_heights = h, total = h))
  }

  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  h_lft_in <- .width_in(cell_padding[["left"]])
  h_rgt_in <- .width_in(cell_padding[["right"]])
  h_pad_in <- h_lft_in + h_rgt_in
  hdr_gp   <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"),
                                   line_height)
  gp_key   <- paste0("header_row_lh", line_height)
  col_w    <- vapply(resolved_cols, function(cs) cs$width_in %||% 0, numeric(1L))

  row_heights <- vapply(seq_len(spans$R), function(r) {
    cells <- spans$cells_by_row[[r]]
    hs <- vapply(cells, function(cell) {
      if (!nzchar(cell$text)) return(0)
      span_w <- sum(col_w[cell$start:cell$end])
      label  <- .wrap_header_cell(cell$text, span_w, h_pad_in, hdr_gp, breaks)
      nlines <- max(1L, length(strsplit(label, "\n", fixed = TRUE)[[1L]]))
      h_grob <- .measure_text_dims_in(label, hdr_gp, gp_key, cache)$h
      h_line <- nlines * .height_in(grid::stringHeight("M"))
      extra  <- if (nlines > 1L) wrap_extra_pad_in else 0
      max(h_grob, h_line) + extra
    }, numeric(1L))
    (if (length(hs) > 0L) max(hs) else 0) + v_pad_in
  }, numeric(1L))

  list(row_heights = row_heights, total = sum(row_heights))
}

# Slice a full-table span structure down to the columns shown on one page.
# `col_group_idx` is the vector of full column indices for the page (group
# columns first, then a contiguous data range).  Because multi-column spans
# are atomic in pagination and group columns are singletons, every span cell
# is either wholly on the page or wholly off it; on-page cells are re-indexed
# to the page-local column positions.
.slice_header_spans <- function(spans, col_group_idx) {
  loc <- function(full_j) match(full_j, col_group_idx)
  cells_by_row <- lapply(spans$cells_by_row, function(cells) {
    keep <- list()
    for (cell in cells) {
      cols <- cell$start:cell$end
      if (all(cols %in% col_group_idx)) {
        keep[[length(keep) + 1L]] <- list(start = loc(cell$start),
                                          end   = loc(cell$end),
                                          text  = cell$text)
      }
    }
    keep
  })
  list(R = spans$R, cells_by_row = cells_by_row)
}

# Measure height of a continuation-marker row
.measure_cont_row_height <- function(row_cont_msg, gp_tbl, cell_padding,
                                     line_height) {
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  cont_gp  <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "continued"),
                                   line_height)
  grob     <- grid::textGrob(row_cont_msg, gp = cont_gp)
  h_grob   <- .height_in(grid::grobHeight(grob))
  h_line   <- .height_in(grid::stringHeight("M"))
  max(h_grob, h_line) + v_pad_in
}

# ---------------------------------------------------------------------------
# gpar helpers
# ---------------------------------------------------------------------------

# Return a gpar identical to `gp` but with lineheight set to `lh`, unless the
# gpar already carries an explicit lineheight — in which case that value wins.
.gp_with_lineheight <- function(gp, lh) {
  fields <- as.list(gp)
  if (is.null(fields$lineheight)) {
    fields$lineheight <- lh
  }
  do.call(grid::gpar, fields)
}

# ---------------------------------------------------------------------------
# Group boundary helpers
# ---------------------------------------------------------------------------

# Identify row indices that start a new group
.compute_group_starts <- function(data, group_vars) {
  if (length(group_vars) == 0L || nrow(data) == 0L) return(integer(0L))
  n <- nrow(data)
  starts <- 1L
  for (i in seq_len(n - 1L)) {
    for (gv in group_vars) {
      if (!identical(data[[gv]][i], data[[gv]][i + 1L])) {
        starts <- c(starts, i + 1L)
        break
      }
    }
  }
  starts
}

# Compute group sizes (number of rows per group) from data and group vars.
# Returns a named integer vector: name = row index of group start (as string),
# value = number of rows in that group.  Group is defined by the *full*
# group_vars vector — i.e. the most-specific (innermost) grouping.
.compute_group_sizes <- function(data, group_vars) {
  if (length(group_vars) == 0L || nrow(data) == 0L) return(integer(0L))
  all_starts <- .compute_group_starts(data, group_vars)
  ends       <- c(all_starts[-1L] - 1L, nrow(data))
  sizes      <- ends - all_starts + 1L
  stats::setNames(sizes, as.character(all_starts))
}

# Per-group-start metadata for group-rule visibility and width.
#
# Returns a list with two named integer vectors keyed by group_start row
# index (as string):
#
#   $sizes  — for each group_start row i, the size of the group at the
#             *outermost* level that changed between rows i-1 and i (the
#             count of rows in `data` whose group_vars[1..k] all match
#             row i's values, where k is the outermost changing level).
#             The first group_start is NA (no transition before it).
#   $levels — the column index k (1-based, into group_vars) of the
#             outermost changing level.  NA for the first group_start.
#
# This differs from .compute_group_sizes(), which always uses the full
# group_vars vector for sizing.  When a transition crosses an outer-group
# boundary but the new innermost group has only a single row (e.g. Cohort
# changes from 1 to 2 and Cohort 2 happens to start with a one-row Visit),
# .compute_group_sizes() returns 1 and the rule gets suppressed; here the
# outer Cohort group size is returned so a meaningful boundary still gets
# a rule.  $levels lets callers draw a partial-width rule that starts at
# the changing column instead of always spanning the full table width.
#
# Used only when tbl$simplify_rowspan is TRUE.
.compute_group_rule_info <- function(data, group_vars) {
  if (length(group_vars) == 0L || nrow(data) == 0L) {
    return(list(sizes = integer(0L), levels = integer(0L)))
  }
  starts <- .compute_group_starts(data, group_vars)
  sizes  <- rep(NA_integer_, length(starts))
  levels <- rep(NA_integer_, length(starts))
  names(sizes)  <- as.character(starts)
  names(levels) <- as.character(starts)
  if (length(starts) <= 1L) return(list(sizes = sizes, levels = levels))

  for (idx in seq_along(starts)[-1L]) {
    i      <- starts[[idx]]
    i_prev <- i - 1L
    for (k in seq_along(group_vars)) {
      if (!identical(data[[group_vars[[k]]]][[i_prev]],
                     data[[group_vars[[k]]]][[i]])) {
        # Outermost changing level is k; count rows whose group_vars[1..k]
        # all equal row i's values.
        cols <- group_vars[seq_len(k)]
        mask <- rep(TRUE, nrow(data))
        for (gv in cols) {
          v      <- data[[gv]]
          target <- data[[gv]][[i]]
          if (is.na(target)) {
            mask <- mask & is.na(v)
          } else {
            mask <- mask & !is.na(v) & v == target
          }
        }
        sizes[[idx]]  <- sum(mask)
        levels[[idx]] <- k
        break
      }
    }
  }
  list(sizes = sizes, levels = levels)
}

# ---------------------------------------------------------------------------
# String / cell formatting helpers
# ---------------------------------------------------------------------------

# Format a single cell value, replacing NA
.fmt_cell <- function(val, na_string) {
  if (is.na(val)) na_string else as.character(val)
}

# Format a vector of cell values
.fmt_cell_vec <- function(vec, na_string) {
  ifelse(is.na(vec), na_string, as.character(vec))
}

# Split a column's strings into header lines and (deduped, sampled) data
# values.  Used when each kind of text needs to be measured with a different
# gpar (the header_row gpar is typically bold while cells use a regular
# weight; a header rendered in bold is wider than the same string measured
# in regular weight, so a column auto-sized against the regular-weight
# measurement undersizes its bold header).
.split_col_strings <- function(col_vec, label, na_string, max_rows) {
  data_strs <- unique(.fmt_cell_vec(col_vec, na_string))
  if (is.finite(max_rows) && length(data_strs) > max_rows) {
    data_strs <- data_strs[order(nchar(data_strs), decreasing = TRUE)[
      seq_len(max_rows)]]
  }
  hdr_lines <- if (is.null(label) || !nzchar(label)) {
    character(0L)
  } else {
    strsplit(label, "\n", fixed = TRUE)[[1L]]
  }
  list(header = hdr_lines, data = data_strs)
}

# Collect unique strings for a column (header + data), limited by max_rows
.collect_col_strings <- function(col_vec, label, na_string, max_rows) {
  data_strs <- unique(.fmt_cell_vec(col_vec, na_string))
  # Sort descending by nchar and take top max_rows
  if (is.finite(max_rows) && length(data_strs) > max_rows) {
    data_strs <- data_strs[order(nchar(data_strs), decreasing = TRUE)[
      seq_len(max_rows)]]
  }
  c(strsplit(label, "\n", fixed = TRUE)[[1L]], data_strs)
}

# ---------------------------------------------------------------------------
# Spanning (multi-row) column header helpers
# ---------------------------------------------------------------------------

# Split a header label into segments on `sep`, preserving trailing empty
# fields (which strsplit() drops).  A blank field is produced by two
# separators back-to-back, so "" between them must survive.
.split_header_label <- function(label, sep) {
  if (!nzchar(label)) return("")
  segs <- strsplit(label, sep, fixed = TRUE)[[1L]]
  m     <- gregexpr(sep, label, fixed = TRUE)[[1L]]
  n_sep <- if (length(m) == 1L && m[[1L]] == -1L) 0L else length(m)
  want  <- n_sep + 1L
  if (length(segs) < want) segs <- c(segs, rep("", want - length(segs)))
  if (length(segs) == 0L) segs <- ""
  segs
}

# Compute the multi-row / spanning structure of a set of column header labels.
#
# `labels`  : character vector of full labels, in display order (group
#             columns first, then data columns).
# `sep`     : separator token, or NULL / a single NA to disable the feature.
# `n_grp`   : number of leading row-header (group) columns.
#
# Returns a list:
#   $R            integer number of stacked header rows.
#   $cells_by_row list length R; each element a list of cells partitioning
#                 columns 1..n.  A cell is list(start, end, text) where
#                 `text` is the DISPLAY (right-trimmed) label for that cell.
#                 Empty cells are single-column with text = "".
#   $spanned_gap  logical length n-1; TRUE where a multi-column cell covers
#                 the gap between column j and j+1 (used for atomic
#                 pagination).
#   $leaf_labels  character length n; the display (trimmed) bottom-row
#                 segment per column (fed to per-column width measurement).
#
# Bottom-aligned: a column with fewer segments than R fills the BOTTOM rows.
# Spans are detected by a closed-boundary refinement (hierarchical): merges
# happen only within a shared parent span, empty cells are transparent
# singletons, and the group/data divide is always a hard boundary.
#
# When the feature is off, no label contains `sep`, or R collapses to 1, the
# trivial single-row structure is returned with labels verbatim so that
# downstream measurement and drawing are byte-identical to the pre-feature
# behaviour.
.compute_header_spans <- function(labels, sep, n_grp) {
  n <- length(labels)

  trivial <- function() {
    list(
      R            = 1L,
      cells_by_row = list(lapply(seq_len(n), function(j) {
        list(start = j, end = j, text = labels[[j]])
      })),
      spanned_gap  = if (n >= 2L) rep(FALSE, n - 1L) else logical(0L),
      leaf_labels  = labels
    )
  }

  if (is.null(sep) || .is_single_na(sep) || n == 0L) return(trivial())

  seg_list <- lapply(labels, .split_header_label, sep = sep)
  R <- max(vapply(seg_list, length, integer(1L)))
  if (R <= 1L) return(trivial())

  # Bottom-aligned segment matrices: raw for merge comparison, display
  # (right-trimmed) for rendering and width measurement.
  S_raw <- matrix("", nrow = R, ncol = n)
  for (j in seq_len(n)) {
    s <- seg_list[[j]]
    k <- length(s)
    if (k > 0L) S_raw[(R - k + 1L):R, j] <- s
  }
  S_disp <- matrix(sub("[ \t]+$", "", S_raw), nrow = R, ncol = n)

  n_gap        <- max(0L, n - 1L)
  closed       <- rep(FALSE, n_gap)
  if (n_grp > 0L && n_grp < n) closed[[n_grp]] <- TRUE  # group/data divide
  spanned_gap  <- rep(FALSE, n_gap)
  cells_by_row <- vector("list", R)

  for (r in seq_len(R)) {
    cells <- list()
    j <- 1L
    while (j <= n) {
      k <- j
      # Extend the run while the next gap is open and both cells share equal
      # non-empty raw text (empty cells stop the run -> singletons).
      while (k < n && !closed[[k]] &&
             nzchar(S_raw[r, k]) &&
             identical(S_raw[r, k], S_raw[r, k + 1L])) {
        k <- k + 1L
      }
      cells[[length(cells) + 1L]] <- list(start = j, end = k,
                                          text = S_disp[r, j])
      if (k > j) spanned_gap[j:(k - 1L)] <- TRUE
      j <- k + 1L
    }
    cells_by_row[[r]] <- cells

    # Close boundaries for lower rows: a gap not inside the same non-empty
    # cell becomes closed, UNLESS both sides are empty (empties stay
    # transparent so a shared super-header below an empty top row can span).
    if (r < R && n_gap > 0L) {
      for (gap in seq_len(n_gap)) {
        if (closed[[gap]]) next
        same_cell <- any(vapply(cells, function(c) {
          c$start <= gap && c$end >= gap + 1L
        }, logical(1L)))
        if (same_cell) next
        if (nzchar(S_raw[r, gap]) || nzchar(S_raw[r, gap + 1L])) {
          closed[[gap]] <- TRUE
        }
      }
    }
  }

  list(R = R, cells_by_row = cells_by_row, spanned_gap = spanned_gap,
       leaf_labels = S_disp[R, ])
}

# ---------------------------------------------------------------------------
# Unit conversion helpers
# ---------------------------------------------------------------------------

# Convert a grid unit to inches (width context).
.width_in <- function(x) grid::convertWidth(x, "inches", valueOnly = TRUE)

# Convert a grid unit to inches (height context).
.height_in <- function(x) grid::convertHeight(x, "inches", valueOnly = TRUE)

# ---------------------------------------------------------------------------
# Text measurement helpers
# ---------------------------------------------------------------------------

# Look up or measure (width, height) for `s` under `gp`, caching both when
# an environment is supplied.  `gp_key` is a stable structural key for `gp`
# (e.g. paste0("data_row_lh", line_height)) so callers using the same gp
# share entries without hashing the gpar field-by-field per lookup.  When
# `gp_key` is NULL the cache key is just the string -- appropriate for
# caches whose entries are all measured under one gp (the caller owns
# that invariant).
#
# When the cache misses we build the textGrob once and read BOTH dimensions
# from it -- consolidating what would otherwise be two separate textGrob
# constructions if a later caller needs the other dimension of the same
# (gp, string).  Each construction re-runs grid's gpar validation, which
# is the dominant cost; avoiding the duplicate is the point.
.measure_text_dims_in <- function(s, gp, gp_key = NULL, cache = NULL) {
  if (!nzchar(s)) return(list(w = 0, h = 0))
  if (!is.null(cache)) {
    key <- if (is.null(gp_key)) s else paste0(gp_key, "\x01", s)
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
  }
  # D-48 safety guard.  After Phases 1/2 every internal caller runs
  # inside the metric device opened by `.open_metric_device()`.  A
  # future regression that forgets to open one would produce
  # confusing downstream errors (convertWidth/convertHeight against
  # the null device returns 0 or NA depending on grid version);
  # fail fast here with a clear message instead.  Skipped on cache
  # hits, so the cost is paid only on the slow path.
  if (grDevices::dev.cur() == 1L) {
    rlang::abort(paste0(
      "Internal: .measure_text_dims_in() requires an active graphics ",
      "device.  This is a bug in writetfl -- the caller should be ",
      "invoked under `.open_metric_device()`."
    ))
  }
  g <- grid::textGrob(s, gp = gp)
  out <- list(w = .width_in(grid::grobWidth(g)),
              h = .height_in(grid::grobHeight(g)))
  if (!is.null(cache)) assign(key, out, envir = cache)
  out
}

# Measure the maximum rendered text width (in inches) for a vector of strings.
# Uses textGrob rather than stringWidth() because stringWidth() does not
# accept a gp argument in all grid versions.
#
# When a `cache` env and `gp_key` are supplied, lookups go through the
# consolidated (string -> (w, h)) cache from `.measure_text_dims_in()` so a
# later height query for the same (string, gp) reuses the textGrob.
.measure_max_string_width <- function(strings, gp, gp_key = NULL,
                                      cache = NULL) {
  if (length(strings) == 0L) return(0)
  # Dedupe up front: real-world callers pass cell-string vectors where the
  # same value typically appears in many rows (e.g. category labels, NA
  # strings), so this saves grid round-trips with no behaviour change.
  uniq <- unique(strings)
  if (!is.null(cache) && !is.null(gp_key)) {
    return(max(vapply(uniq, function(s) {
      lines <- strsplit(s, "\n", fixed = TRUE)[[1L]]
      max(vapply(lines,
                 function(ln) .measure_text_dims_in(ln, gp, gp_key, cache)$w,
                 numeric(1L)))
    }, numeric(1L))))
  }
  max(vapply(uniq, function(s) {
    lines <- strsplit(s, "\n", fixed = TRUE)[[1L]]
    max(vapply(lines, function(ln) {
      grob <- grid::textGrob(ln, gp = gp)
      .width_in(grid::grobWidth(grob))
    }, numeric(1L)))
  }, numeric(1L)))
}

# Word-wrap a string to fit within available_w_in inches.
#
# Default-breaks shim around .wrap_string() (R/wrap.R).  Used by callers that
# do not have a tfl_table in scope - the page-level character-content path
# in R/draw.R::draw_content() and the caption / footnote wrapper in
# R/normalize.R::wrap_normalized_text().  tfl_table cell and header
# rendering call .wrap_string() directly with tbl$wrap_breaks so the
# user-configured break spec applies.
#
# Must be called while a viewport with the target font context is active.
.wrap_text <- function(text, available_w_in, gp, ...) {
  .wrap_string(text, available_w_in, gp, wrap_breaks_default(), ...)
}

# ---------------------------------------------------------------------------
# gpar resolution helpers
# ---------------------------------------------------------------------------

# Resolve table-level gp key (with inheritance from gp$table)
.resolve_table_gp <- function(gp_list, key) {
  base     <- if (inherits(gp_list, "gpar")) gp_list else
              gp_list[["table"]] %||% grid::gpar()
  override <- if (is.list(gp_list)) gp_list[[key]] else NULL

  defaults <- list(
    header_row     = grid::gpar(fontface = "bold"),
    continued      = grid::gpar(fontface = "italic"),
    col_header_rule = grid::gpar(lwd = 1),
    col_header_span_rule = grid::gpar(lwd = 1),
    group_rule     = grid::gpar(lwd = 0.5, lty = "dotted"),
    row_rule       = grid::gpar(lwd = 0.5),
    row_header_sep = grid::gpar(lwd = 0.5)
  )

  result <- merge_gpar(base, defaults[[key]] %||% grid::gpar())
  if (!is.null(override)) result <- merge_gpar(result, override)
  result
}

# Resolve gp for a table cell (group col or data col)
.resolve_table_cell_gp <- function(gp_list, is_group_col) {
  key <- if (is_group_col) "group_col" else "data_row"
  .resolve_table_gp(gp_list, key)
}

# ---------------------------------------------------------------------------
# Alignment helper
# ---------------------------------------------------------------------------

# Default alignment by column type
.default_align <- function(col_vec) {
  if (is.numeric(col_vec)) "right" else "left"
}
