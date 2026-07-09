# wrap.R - Word wrap module for tfl_table()
#
# Owns text wrapping inside table cells and column headers, plus the
# water-from-top algorithm that narrows wrap-eligible columns when the
# table is wider than the page.
#
# All functions are internal.  The page-level character-content path in
# R/draw.R and the caption / footnote wrapper in R/normalize.R reach the
# core algorithm via the .wrap_text() shim in R/table_utils.R, which
# forwards to .wrap_string() with the package default breaks.
#
# Disable: tfl_table(wrap_cols = FALSE) bypasses the whole module.
#
# Public-internal entry points:
#   wrap_breaks(drop, keep_before)       - constructor
#   wrap_breaks_default()                - package default
#   .is_wrap_breaks(x)                   - predicate
#   .wrap_string(text, avail_in, gp, breaks)
#   .column_has_breakable_text(strings, breaks)
#   .column_min_token_width_in(strings, gp, breaks)
#   .compute_wrapped_widths(widths_in, resolved_cols, ...)
#   .wrap_label_for_width(label, width_in, gp, breaks)

# ---------------------------------------------------------------------------
# wrap_breaks() - break-character spec
# ---------------------------------------------------------------------------

#' Specify how strings are broken when wrapping table text
#'
#' A `wrap_breaks` object lists the characters at which `.wrap_string()` is
#' allowed to insert a line break.  Two modes are supported:
#'
#' * `drop` characters are consumed at the break point.  The default
#'   (`" "` and `"\t"`) means runs of whitespace disappear when a wrap
#'   occurs there but stay inline otherwise.
#' * `keep_before` characters stay on the left of the break - the character
#'   is preserved at the end of the upper line and the *next* character
#'   starts the new line.  Typical use: `"-"` so that a hyphenated term
#'   like `"placebo-controlled"` can wrap to `"placebo-\ncontrolled"`.
#'
#' `drop` and `keep_before` must be disjoint single-character vectors.
#'
#' @param drop Character vector of single-character break points consumed
#'   at the break.  Defaults to `c(" ", "\t")`.
#' @param keep_before Character vector of single-character break points
#'   preserved on the left of the break.  Defaults to `character(0)`.
#'
#' @return A list of class `"wrap_breaks"` with components `drop` and
#'   `keep_before`.
#'
#' @keywords internal
wrap_breaks <- function(drop        = c(" ", "\t"),
                        keep_before = character(0L)) {
  drop        <- if (is.null(drop))        character(0L) else drop
  keep_before <- if (is.null(keep_before)) character(0L) else keep_before
  if (!is.character(drop) || anyNA(drop)) {
    rlang::abort("`drop` must be a character vector with no NAs.")
  }
  if (!is.character(keep_before) || anyNA(keep_before)) {
    rlang::abort("`keep_before` must be a character vector with no NAs.")
  }
  if (any(nchar(drop) != 1L)) {
    rlang::abort("Every `drop` element must be a single character.")
  }
  if (any(nchar(keep_before) != 1L)) {
    rlang::abort("Every `keep_before` element must be a single character.")
  }
  overlap <- intersect(drop, keep_before)
  if (length(overlap) > 0L) {
    rlang::abort(paste0(
      "`drop` and `keep_before` must be disjoint. Overlapping characters: ",
      paste(shQuote(overlap), collapse = ", ")
    ))
  }
  structure(
    list(drop = unique(drop), keep_before = unique(keep_before)),
    class = "wrap_breaks"
  )
}

#' Package-default break spec (whitespace only).
#' @keywords internal
wrap_breaks_default <- function() {
  wrap_breaks(drop = c(" ", "\t"), keep_before = character(0L))
}

#' Predicate for wrap_breaks objects.
#' @keywords internal
.is_wrap_breaks <- function(x) inherits(x, "wrap_breaks")

# ---------------------------------------------------------------------------
# Tokenizer
# ---------------------------------------------------------------------------

# Tokenize one paragraph (no embedded \n) into a list of break-delimited
# chunks.  Each chunk is a list with:
#   $text - the substring that becomes part of a rendered line
#   $lead - the separator that prepends this chunk when continuing on the
#           same line, dropped when this chunk starts a fresh line
#
# A `drop` character produces a chunk boundary AND becomes the next chunk's
# $lead.  A `keep_before` character is appended to the preceding chunk's
# $text and forces a boundary; the following chunk has $lead = "".
#
# The first chunk always has $lead = "".  An empty input returns list().
.tokenize_for_wrap <- function(s, breaks) {
  if (!nzchar(s)) return(list())
  drop_chars <- breaks$drop
  keep_chars <- breaks$keep_before

  chars <- strsplit(s, "", fixed = TRUE)[[1L]]
  n     <- length(chars)
  if (n == 0L) return(list())

  # Track each token by its [start, end] position in `s` rather than
  # accumulating characters and pasting on flush.  `substr(s, st, ed)` is
  # one C call per token; the previous `paste(cur_buf[seq_len(cur_n)],
  # collapse = "")` allocated and joined cur_n elements per token.
  tokens    <- vector("list", n)       # over-allocate; trim at end
  k         <- 0L
  cur_start <- 0L                       # 0 means "no token in progress"
  cur_end   <- 0L
  pending   <- ""

  flush <- function() {
    if (cur_start > 0L) {
      k <<- k + 1L
      tokens[[k]] <<- list(
        text = substr(s, cur_start, cur_end),
        lead = pending
      )
      cur_start <<- 0L
      pending   <<- ""
    }
  }

  for (i in seq_len(n)) {
    ch <- chars[[i]]
    if (length(drop_chars) > 0L && ch %in% drop_chars) {
      flush()
      pending <- ch
    } else if (length(keep_chars) > 0L && ch %in% keep_chars) {
      if (cur_start == 0L) cur_start <- i
      cur_end <- i
      flush()
      pending <- ""
    } else {
      if (cur_start == 0L) cur_start <- i
      cur_end <- i
    }
  }
  flush()

  if (k == 0L) list() else tokens[seq_len(k)]
}

# ---------------------------------------------------------------------------
# .wrap_string() - wrap one string to fit a width
# ---------------------------------------------------------------------------

# Width of a string under the active viewport's font context, in inches.
#
# `cache`, if supplied, is an environment used as a (string -> width) memo
# scoped to the caller's lifetime.  The caller is responsible for ensuring
# every cache entry was measured under the same `gp`.
#
# This helper is in a hot loop (wrap module re-measures candidate strings
# many times per cell).  An earlier attempt to delegate through
# `.measure_text_dims_in()` for a unified cache cost ~20-30% on
# wrap_heavy / big_df / preview_iris -- the double function call plus
# list-wrapping per cache hit was unaffordable here.  The two helpers
# share a textGrob construction strategy but stay separate functions for
# the inner loop's benefit.
.measure_text_width_in <- function(s, gp, cache = NULL) {
  if (!nzchar(s)) return(0)
  if (!is.null(cache) && exists(s, envir = cache, inherits = FALSE)) {
    return(get(s, envir = cache, inherits = FALSE))
  }
  w <- .width_in(grid::grobWidth(grid::textGrob(s, gp = gp)))
  if (!is.null(cache)) assign(s, w, envir = cache)
  w
}

#' Expand tab characters in one line of text to spaces
#'
#' The PDF graphics device cannot measure or render the tab glyph (0x09): it
#' warns "font width unknown" and treats the tab as zero width, so a tab in
#' cell or page text would silently collapse.  Tabs are therefore expanded to
#' spaces before any measuring or drawing.
#'
#' @param s A single character string with no embedded newline.
#' @param ... Ignored.
#' @param tab_indent_spaces Number of spaces a *leading* (indentation) tab —
#'   one preceded only by whitespace — is expanded to.  Default `2`, matching
#'   the common "a tab indents by two spaces" convention.
#' @param tab_infix_spaces Number of spaces an *in-line* tab — one with
#'   non-whitespace to its left — is expanded to.  Default `1`; the resulting
#'   space then behaves as an ordinary breakable space.
#'
#' @return `s` with tab characters replaced by spaces.  Strings containing no
#'   tab are returned untouched (fast path).
#'
#' @keywords internal
.convert_tabs <- function(s, ..., tab_indent_spaces = 2L, tab_infix_spaces = 1L) {
  if (!grepl("\t", s, fixed = TRUE)) return(s)
  indent_fill <- strrep(" ", tab_indent_spaces)
  infix_fill  <- strrep(" ", tab_infix_spaces)
  chars   <- strsplit(s, "", fixed = TRUE)[[1L]]
  in_lead <- TRUE
  for (i in seq_along(chars)) {
    ch <- chars[[i]]
    if (ch == "\t") {
      chars[[i]] <- if (in_lead) indent_fill else infix_fill
    } else if (ch != " ") {
      in_lead <- FALSE
    }
  }
  paste0(chars, collapse = "")
}

#' Wrap text to fit a target width, preserving paragraph breaks.
#'
#' Greedy left-to-right packing.  Paragraphs (separated by `\n` in `text`)
#' are wrapped independently and the results re-joined with `\n`.  Within
#' a paragraph the break-character spec controls where breaks may occur;
#' a single token wider than `available_w_in` is emitted unchanged on its
#' own line because there is no valid break point inside it.
#'
#' @param text Single character string.
#' @param available_w_in Numeric, available width in inches.
#' @param gp A `gpar()` for measurement font context.
#' @param breaks A `wrap_breaks` object; if `NULL`, the package default.
#' @inheritDotParams .convert_tabs tab_indent_spaces tab_infix_spaces
#'
#' @return A single character string, possibly with `\n` inserted at break
#'   points.
#'
#' @keywords internal
.wrap_string <- function(text, available_w_in, gp,
                         breaks = wrap_breaks_default(), ...) {
  if (is.null(text) || !nzchar(text)) return(text)
  if (is.null(breaks)) breaks <- wrap_breaks_default()

  # Per-call width memo: within one wrap the same gp is used throughout, and
  # the greedy walk re-measures many overlapping `cand` strings.  Sharing one
  # cache across paragraphs deduplicates those calls.
  width_cache <- new.env(hash = TRUE, parent = emptyenv())

  paragraphs <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  wrapped    <- vapply(paragraphs, function(para) {
    if (!nzchar(para)) return("")
    .wrap_paragraph(para, available_w_in, gp, breaks, width_cache, ...)
  }, character(1L))
  paste(wrapped, collapse = "\n")
}

# Maximal leading run of `drop` characters at the start of `s`, as a string
# (e.g. the indentation on `"   Indented label"`).  Returns `""` when there is
# none.  Used by `.wrap_paragraph()` to re-attach a paragraph's prefix that the
# tokenizer would otherwise consume.  Fast path: a single `substr()` check
# short-circuits the common no-indentation case before any `strsplit()`.
.leading_drop_run <- function(s, drop_chars) {
  if (length(drop_chars) == 0L || !nzchar(s)) return("")
  if (!(substr(s, 1L, 1L) %in% drop_chars)) return("")
  chars <- strsplit(s, "", fixed = TRUE)[[1L]]
  n     <- length(chars)
  k     <- 1L
  while (k < n && chars[[k + 1L]] %in% drop_chars) k <- k + 1L
  substr(s, 1L, k)
}

.wrap_paragraph <- function(para, available_w_in, gp, breaks,
                            width_cache = NULL, ...) {
  # Expand tabs to spaces first so leading indentation is measurable and any
  # in-line tab becomes an ordinary space (the device cannot render tabs).
  para <- .convert_tabs(para, ...)

  # Preserve leading indentation as a hanging indent.  The tokenizer treats a
  # run of `drop` characters as a between-token separator and `.wrap_paragraph()`
  # drops the first token's separator, so a paragraph like `"   Indented label"`
  # would otherwise lose its prefix entirely.  Capture the leading `drop` run,
  # wrap the remaining body against the width reduced by the indent, then
  # re-attach the prefix to *every* wrapped line so indented text stays
  # indented across the wrap.
  lead_ws <- .leading_drop_run(para, breaks$drop)
  body    <- if (nzchar(lead_ws)) substring(para, nchar(lead_ws) + 1L) else para

  tokens <- .tokenize_for_wrap(body, breaks)
  # A whitespace-only paragraph tokenizes to nothing; return the prefix so its
  # spacing survives rather than collapsing to "".
  if (length(tokens) == 0L) return(lead_ws)

  # Width taken up by the indent shrinks the room each line has for body text.
  indent_w <- if (nzchar(lead_ws)) {
    .measure_text_width_in(lead_ws, gp, width_cache)
  } else 0
  body_w <- max(0, available_w_in - indent_w)

  lines        <- character(0L)
  current_line <- ""

  for (tok in tokens) {
    if (!nzchar(current_line)) {
      current_line <- tok$text
      next
    }
    cand <- paste0(current_line, tok$lead, tok$text)
    if (.measure_text_width_in(cand, gp, width_cache) <=
        body_w + 1e-6) {
      current_line <- cand
    } else {
      lines        <- c(lines, current_line)
      current_line <- tok$text
    }
  }
  if (nzchar(current_line)) lines <- c(lines, current_line)
  if (nzchar(lead_ws)) lines <- paste0(lead_ws, lines)
  paste(lines, collapse = "\n")
}

# ---------------------------------------------------------------------------
# Auto-detection and floor computation
# ---------------------------------------------------------------------------

#' Does any string in `strings` contain a break character?
#'
#' Used by the `wrap_cols = "auto"` path: a column with no breakable text
#' is skipped because no amount of narrowing can wrap it.
#'
#' @keywords internal
.column_has_breakable_text <- function(strings, breaks) {
  if (length(strings) == 0L) return(FALSE)
  break_chars <- c(breaks$drop, breaks$keep_before)
  if (length(break_chars) == 0L) return(FALSE)
  pat <- paste0("[", paste(vapply(break_chars, .regex_escape_char, ""),
                            collapse = ""), "]")
  any(grepl(pat, strings, perl = TRUE))
}

# Escape a single character for use inside a regex character class.
.regex_escape_char <- function(ch) {
  if (ch %in% c("\\", "]", "^", "-")) paste0("\\", ch) else ch
}

#' Width (inches) of the widest unbreakable token across a column's strings.
#'
#' This is the wrapping floor: a column cannot be narrowed below the width
#' needed to render its longest single token.  Tabs are expanded to spaces
#' first (matching the table draw path) so the floor agrees with the rendered
#' text.
#'
#' @inheritDotParams .convert_tabs tab_indent_spaces tab_infix_spaces
#' @keywords internal
.column_min_token_width_in <- function(strings, gp, breaks, ...) {
  if (length(strings) == 0L) return(0)
  # Single shared cache across the column: tokens like "the", units, and
  # other short repeats appear in many cells and would otherwise each
  # incur a fresh textGrob+grobWidth+convertWidth round-trip.
  cache <- new.env(hash = TRUE, parent = emptyenv())
  max(vapply(strings, function(s) {
    if (!nzchar(s)) return(0)
    paragraphs <- strsplit(s, "\n", fixed = TRUE)[[1L]]
    max(vapply(paragraphs, function(p) {
      p      <- .convert_tabs(p, ...)
      tokens <- .tokenize_for_wrap(p, breaks)
      if (length(tokens) == 0L) return(0)
      # A hanging indent (preserved by .wrap_paragraph) widens every wrapped
      # line, so the floor must leave room for indent + widest token or the
      # indented lines would clip when the column is narrowed.
      indent_w <- .measure_text_width_in(.leading_drop_run(p, breaks$drop),
                                         gp, cache)
      indent_w + max(vapply(tokens, function(tok) {
        .measure_text_width_in(tok$text, gp, cache)
      }, numeric(1L)))
    }, numeric(1L)))
  }, numeric(1L)))
}

# ---------------------------------------------------------------------------
# Header / cell label wrapping helper
# ---------------------------------------------------------------------------

#' Wrap a column-header label (or any single string) to a target width
#' minus left+right horizontal padding.
#'
#' @keywords internal
.wrap_label_for_width <- function(label, width_in, h_pad_in, gp, breaks) {
  if (is.null(label) || !nzchar(label)) return(label)
  inner <- max(0, width_in - h_pad_in)
  .wrap_string(label, inner, gp, breaks)
}

# ---------------------------------------------------------------------------
# .compute_col_min_widths() - per-column minimum (floor) widths
# ---------------------------------------------------------------------------

#' Per-column minimum survivable width in inches
#'
#' For wrap-eligible columns, the minimum is
#' `max(min_col_width, longest_unbreakable_token + h_pad)`, measured under
#' both the cell and header gpars and taking the larger so a bold-rendered
#' header token cannot be undersized.  For non-wrap-eligible columns the
#' minimum equals the supplied `widths_natural` (those columns cannot
#' shrink without overflowing).
#'
#' Opens its own scratch PDF device and outer viewport for measurement.
#'
#' @param widths_natural Numeric vector of per-column natural widths
#'   (inches).  Used as the floor for non-wrap-eligible columns.
#' @param resolved_cols The `resolve_col_specs()` output.
#' @param data The full data frame from `tbl$data`.
#' @param tbl A `tfl_table` object (used for `gp`, `cell_padding`,
#'   `line_height`, `na_string`, `max_measure_rows`, `min_col_width`,
#'   `wrap_breaks`).
#' @param h_pad_in Horizontal cell padding (left+right) in inches.
#' @param min_in `min_col_width` resolved to inches.
#' @param pg_width,pg_height,margins Forwarded to the scratch device.
#'
#' @return Numeric vector of per-column minimum widths in inches.
#'
#' @keywords internal
.compute_col_min_widths <- function(widths_natural, resolved_cols, data, tbl,
                                     h_pad_in, min_in,
                                     pg_width, pg_height, margins) {
  n        <- length(resolved_cols)
  breaks   <- tbl$wrap_breaks %||% wrap_breaks_default()
  na_str   <- tbl$na_string
  max_rows <- tbl$max_measure_rows

  # D-48: relies on the metric device opened upstream by
  # `.open_metric_device()` rather than opening a scratch PDF here.
  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)
  on.exit(grid::popViewport(), add = TRUE)

  vapply(seq_len(n), function(j) {
    cs <- resolved_cols[[j]]
    if (!isTRUE(cs$wrap)) {
      return(widths_natural[[j]])
    }
    cell_gp <- .gp_with_lineheight(
      .resolve_table_cell_gp(tbl$gp, cs$is_group_col), tbl$line_height
    )
    hdr_gp <- .gp_with_lineheight(
      .resolve_table_gp(tbl$gp, "header_row"), tbl$line_height
    )
    parts  <- .split_col_strings(data[[cs$col]], cs$leaf_label %||% cs$label,
                                 na_str, max_rows)
    t_data <- .column_min_token_width_in(parts$data,   cell_gp, breaks)
    t_hdr  <- .column_min_token_width_in(parts$header, hdr_gp,  breaks)
    max(min_in, max(t_data, t_hdr) + h_pad_in)
  }, numeric(1L))
}

# ---------------------------------------------------------------------------
# .water_fill_to_budget() - pure water-from-top given pre-computed mins
# ---------------------------------------------------------------------------

#' Water-fill widths down to a target budget, given pre-computed minimums
#'
#' Pure water-from-top: at each iteration find the widest set of
#' wrap-eligible columns above their floor (`widths_min`) and shrink them
#' together until they meet the next-widest competitor, hit a floor, or
#' absorb the remaining excess.  Returns the per-column widths summing to
#' `≤ budget_in + eps` when feasible.
#'
#' Unlike [`.compute_wrapped_widths()`], this helper does *not* re-measure
#' the per-column floors from cell content — it trusts the supplied
#' `widths_min` vector.  Use this when the floors are computed once and
#' applied to many sub-problems (per-page water-fill under the
#' `col_split_strategy = "balanced"` pipeline).
#'
#' If `sum(widths_min) > budget_in`, the function returns the widths
#' clamped to the floors (sum may still exceed budget); the caller is
#' responsible for detecting that case and paginating differently.
#'
#' @param widths_in Numeric vector of starting widths in inches.
#' @param widths_min Numeric vector of per-column floors in inches.
#' @param wrap_eligible Logical vector; only `TRUE` columns participate
#'   in shrinking.
#' @param budget_in Numeric target sum for `widths_in`.
#'
#' @return Numeric vector of resulting widths.
#'
#' @keywords internal
.water_fill_to_budget <- function(widths_in, widths_min, wrap_eligible,
                                   budget_in) {
  n   <- length(widths_in)
  eps <- 1e-6

  # First snap to floors: nothing can be below its floor.  This handles the
  # case where the caller passed in a width that's already too narrow.
  widths_in <- pmax(widths_in, widths_min)

  max_iter <- 2L * n + 50L
  for (iter in seq_len(max_iter)) {
    excess <- sum(widths_in) - budget_in
    if (excess <= eps) break

    active <- which(wrap_eligible & widths_in > widths_min + eps)
    if (length(active) == 0L) break

    max_w  <- max(widths_in[active])
    at_max <- active[widths_in[active] >= max_w - eps]

    others    <- setdiff(active, at_max)
    next_comp <- if (length(others) > 0L) max(widths_in[others]) else -Inf
    floor_max <- max(widths_min[at_max])
    step_floor   <- max_w - floor_max
    step_compete <- max_w - next_comp
    step_excess  <- excess / length(at_max)
    step <- min(step_floor, step_compete, step_excess)
    if (step <= eps) break

    widths_in[at_max] <- widths_in[at_max] - step
  }

  widths_in
}

# ---------------------------------------------------------------------------
# .reconcile_page_widths() - flatten per-page widths into one per-col vector
# ---------------------------------------------------------------------------

#' Combine per-page width vectors into one per-column vector
#'
#' Non-group columns appear on exactly one page-column-split page; their
#' final width is whatever that page allocated.  Group columns repeat on
#' every page and must be drawn at a single width that satisfies every
#' page; under the `col_split_strategy = "balanced"` design they are pinned
#' at the minimum width across pages so data columns on every page receive
#' the most slack.  This helper enforces both rules and returns a single
#' `numeric(n_cols)` vector with each column's final width.
#'
#' @param per_page_widths List of `numeric` vectors; element `g` is the
#'   per-column width vector for `col_groups[[g]]` (length equals
#'   `length(col_groups[[g]])`).
#' @param col_groups List of integer vectors of column indices per
#'   page-column-split page (as returned by [`paginate_cols()`]).
#' @param n_group_cols Integer scalar; the first `n_group_cols` column
#'   indices are group columns.
#' @param n_cols Total number of columns in the table.
#'
#' @return Numeric vector of length `n_cols`.
#'
#' @keywords internal
.reconcile_page_widths <- function(per_page_widths, col_groups, n_group_cols,
                                    n_cols) {
  widths_out <- rep(NA_real_, n_cols)

  # Group columns: take the MIN width across pages so data cols on every
  # page receive the most slack.
  if (n_group_cols > 0L) {
    grp_idx <- seq_len(n_group_cols)
    for (g in grp_idx) {
      grp_widths <- vapply(seq_along(col_groups), function(p) {
        pos <- match(g, col_groups[[p]])
        if (is.na(pos)) NA_real_ else per_page_widths[[p]][[pos]]
      }, numeric(1L))
      widths_out[[g]] <- min(grp_widths, na.rm = TRUE)
    }
  }

  # Data columns: each appears on exactly one page-column-split page.
  for (p in seq_along(col_groups)) {
    page_idx <- col_groups[[p]]
    page_w   <- per_page_widths[[p]]
    for (k in seq_along(page_idx)) {
      j <- page_idx[[k]]
      if (j > n_group_cols) {
        widths_out[[j]] <- page_w[[k]]
      }
    }
  }

  widths_out
}

# ---------------------------------------------------------------------------
# .compute_wrapped_widths() - water-from-top column narrowing
# ---------------------------------------------------------------------------

#' Iteratively narrow wrap-eligible columns to fit `content_width_in`.
#'
#' Replaces the older single-target `.apply_col_wrapping()` with a fairer
#' "water-from-top" pass: each iteration finds the widest set of
#' wrap-eligible columns above their floor and shrinks them together
#' until the next-lower competitor or a floor is hit.  Floors honour
#' `min_col_width` AND the longest unbreakable token in the column.
#'
#' Deterministic, O(n^2) in column count, n <= ~30 in practice.
#'
#' @param widths_in Numeric vector of current per-column widths in inches.
#' @param resolved_cols The `resolve_col_specs()` output.
#' @param data The full data frame from `tbl$data`.
#' @param tbl A `tfl_table` object (used for `gp`, `cell_padding`,
#'   `line_height`, `na_string`, `max_measure_rows`, `min_col_width`,
#'   `wrap_breaks`).
#' @param content_width_in Numeric target total width in inches.
#' @param h_pad_in Horizontal padding (left+right) in inches.
#' @param min_in `min_col_width` resolved to inches.
#' @param pg_width,pg_height,margins Forwarded to the scratch device.
#'
#' @return Updated `widths_in`.
#'
#' @keywords internal
.compute_wrapped_widths <- function(widths_in, resolved_cols, data, tbl,
                                    content_width_in, h_pad_in, min_in,
                                    pg_width, pg_height, margins) {
  n             <- length(widths_in)
  wrap_eligible <- vapply(resolved_cols, `[[`, logical(1L), "wrap")
  if (!any(wrap_eligible)) return(widths_in)

  breaks   <- tbl$wrap_breaks %||% wrap_breaks_default()
  na_str   <- tbl$na_string
  max_rows <- tbl$max_measure_rows

  # D-48: relies on the metric device opened upstream by
  # `.open_metric_device()` rather than opening a scratch PDF here.
  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)
  on.exit(grid::popViewport(), add = TRUE)

  # Compute per-column floors (only meaningful for wrap-eligible cols).
  # Headers are rendered with the header_row gpar (typically bold) and data
  # cells with the cell gpar (regular).  Measuring the floor with only one
  # of those gpars under-counts the other - a bold header token may be
  # rendered wider than its regular-weight measurement, and the wrap module
  # would then promise the column a width the renderer cannot honour.
  floors <- widths_in
  for (j in which(wrap_eligible)) {
    cs      <- resolved_cols[[j]]
    cell_gp <- .gp_with_lineheight(
      .resolve_table_cell_gp(tbl$gp, cs$is_group_col), tbl$line_height
    )
    hdr_gp <- .gp_with_lineheight(
      .resolve_table_gp(tbl$gp, "header_row"), tbl$line_height
    )
    parts  <- .split_col_strings(data[[cs$col]], cs$leaf_label %||% cs$label,
                                 na_str, max_rows)
    t_data <- .column_min_token_width_in(parts$data,   cell_gp, breaks)
    t_hdr  <- .column_min_token_width_in(parts$header, hdr_gp,  breaks)
    floors[[j]] <- max(min_in, max(t_data, t_hdr) + h_pad_in)
    if (floors[[j]] > widths_in[[j]]) floors[[j]] <- widths_in[[j]]
  }

  # Water-from-top
  eps          <- 1e-6
  max_iter     <- 2L * n + 50L
  for (iter in seq_len(max_iter)) {
    excess <- sum(widths_in) - content_width_in
    if (excess <= eps) break

    active <- which(wrap_eligible & widths_in > floors + eps)
    if (length(active) == 0L) break

    max_w  <- max(widths_in[active])
    at_max <- active[widths_in[active] >= max_w - eps]

    others    <- setdiff(active, at_max)
    next_comp <- if (length(others) > 0L) max(widths_in[others]) else -Inf
    floor_max <- max(floors[at_max])
    step_floor   <- max_w - floor_max
    step_compete <- max_w - next_comp
    step_excess  <- excess / length(at_max)
    step <- min(step_floor, step_compete, step_excess)
    if (step <= eps) break

    widths_in[at_max] <- widths_in[at_max] - step
  }

  widths_in
}

# ---------------------------------------------------------------------------
# .height_balance_widths() - opt-in pass that redistributes width between
# wrap-eligible columns to reduce total table height.
# ---------------------------------------------------------------------------

#' Redistribute widths between wrap-eligible columns to lower total height
#'
#' Opt-in pass triggered by `tfl_table(wrap_balance = "height")`.  Runs after
#' `.compute_wrapped_widths()` (water-fill) and uses a bounded greedy local
#' search: at each iteration find the row whose cells are tallest, identify
#' the wrap-eligible column that drives that row's height (the "bottleneck")
#' and the wrap-eligible column with the most slack (shortest cell content
#' in that row, with room to give up width down to its floor), and try
#' transferring a width delta from slack to bottleneck.  Accept the move
#' that reduces the *total table height* (sum of per-row heights, plus
#' header).  Stop when no transfer at any tested delta improves total
#' height, when `max_iter` is reached, or when `budget_seconds` of
#' wall-time is exhausted.
#'
#' Cell heights at each `(column, width)` pair are cached so repeat
#' measurements during the search are free; with cell-string deduplication
#' inside one column, the total measurement cost is bounded by
#' `n_unique_cells * n_unique_widths_explored` per column.
#'
#' Invariants:
#'  * Total width is preserved exactly (every move is a transfer).
#'  * No column shrinks below its floor (the larger of `min_col_width` and
#'    the rendered width of its longest unbreakable token under either the
#'    cell or header gpar).
#'  * No column grows past its natural width (max content width including
#'    bold-rendered header tokens).
#'  * Any error or invariant violation falls back silently to the input
#'    widths, so opting in cannot produce a *worse* table than the default.
#'
#' Approximation: the cost function ignores the rowspan-style group-cell
#' suppression handled by `.compute_page_row_heights()` - group columns are
#' typically not wrap-eligible (auto-detect skips them), so they don't
#' participate in moves; the approximation only marginally affects which
#' move is "best" when group columns happen to dominate a row's height.
#'
#' @keywords internal
.height_balance_widths <- function(widths_in, resolved_cols, data, tbl,
                                    h_pad_in, na_str, max_rows, breaks,
                                    pg_width, pg_height, margins,
                                    budget_seconds = 1.0,
                                    max_iter       = 20L) {
  original <- widths_in

  wrap_eligible <- vapply(resolved_cols, `[[`, logical(1L), "wrap")
  if (sum(wrap_eligible) < 2L) return(original)

  cell_padding <- tbl$cell_padding
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  wrap_extra_pad_in <- if (!is.null(tbl$wrap_extra_padding)) {
    .height_in(tbl$wrap_extra_padding)
  } else 0
  line_height <- tbl$line_height %||% 1.05
  min_in      <- .width_in(tbl$min_col_width)

  # D-48: relies on the metric device opened upstream by
  # `.open_metric_device()` rather than opening a scratch PDF here.
  # outer_vp pop happens via on.exit so it runs even under tryCatch
  # failure inside the search loop.
  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)
  on.exit(grid::popViewport(), add = TRUE)

  result <- tryCatch({
    .height_balance_widths_impl(
      widths_in = widths_in,
      resolved_cols = resolved_cols,
      data = data, tbl = tbl,
      wrap_eligible = wrap_eligible,
      h_pad_in = h_pad_in,
      v_pad_in = v_pad_in,
      wrap_extra_pad_in = wrap_extra_pad_in,
      line_height = line_height,
      min_in = min_in,
      na_str = na_str, max_rows = max_rows, breaks = breaks,
      budget_seconds = budget_seconds,
      max_iter = max_iter
    )
  }, error = function(e) original)

  # Defensive sanity check before returning.  If anything looks off
  # (length changed, NAs, total width drifted), return the original
  # widths so the caller sees water-fill behavior unchanged.
  if (length(result) != length(original) || anyNA(result) ||
      abs(sum(result) - sum(original)) > 1e-3) {
    return(original)
  }
  result
}

# Search loop kept in its own function for readability; assumes the
# scratch device is already open and an outer viewport is active.
.height_balance_widths_impl <- function(widths_in, resolved_cols, data, tbl,
                                         wrap_eligible, h_pad_in, v_pad_in,
                                         wrap_extra_pad_in, line_height,
                                         min_in, na_str, max_rows, breaks,
                                         budget_seconds, max_iter) {
  n <- length(widths_in)
  eps <- 1e-6

  # Per-column gpars - constant across iterations, so resolve once.
  cell_gps <- lapply(resolved_cols, function(cs) {
    .gp_with_lineheight(
      .resolve_table_cell_gp(tbl$gp, cs$is_group_col), line_height
    )
  })
  hdr_gp <- .gp_with_lineheight(
    .resolve_table_gp(tbl$gp, "header_row"), line_height
  )

  # Pre-extract per-column cell-string vectors (one per column).
  cell_strs_list <- lapply(resolved_cols, function(cs) {
    .fmt_cell_vec(data[[cs$col]], na_str)
  })

  # Per-column floors and natural widths.  Floors prevent shrinking past
  # the column's longest unbreakable token; naturals prevent growing past
  # the column's full content width (no benefit past that).
  floors  <- widths_in
  natural <- widths_in
  for (j in which(wrap_eligible)) {
    cs <- resolved_cols[[j]]
    parts  <- .split_col_strings(data[[cs$col]], cs$label, na_str, max_rows)
    t_data <- .column_min_token_width_in(parts$data,   cell_gps[[j]], breaks)
    t_hdr  <- .column_min_token_width_in(parts$header, hdr_gp,        breaks)
    floors[[j]]  <- max(min_in, max(t_data, t_hdr) + h_pad_in)
    w_data <- .measure_max_string_width(parts$data,   cell_gps[[j]])
    w_hdr  <- .measure_max_string_width(parts$header, hdr_gp)
    natural[[j]] <- max(min_in, max(w_data, w_hdr) + h_pad_in)
    # No clamp on natural: a column whose post-water-fill width is below its
    # natural width SHOULD be allowed to grow back up to natural during
    # height-balance.  The headroom check (natural - widths_in) handles the
    # already-at-or-above-natural case by falling out via headroom <= eps.
    # If floor is above current (an artifact of upstream invariants),
    # clamp so the algorithm doesn't try to shrink an already-narrow column.
    if (floors[[j]]  > widths_in[[j]]) floors[[j]]  <- widths_in[[j]]
  }

  # Cache key: paste0(j, "|", round(width, 3)).  Value: list with header
  # height (no v_pad) and cell heights vector (no v_pad).
  cache <- new.env(hash = TRUE, parent = emptyenv())

  measure_col <- function(j, width) {
    key <- paste0(j, "|", sprintf("%.3f", width))
    if (exists(key, envir = cache, inherits = FALSE)) {
      return(get(key, envir = cache, inherits = FALSE))
    }
    cs    <- resolved_cols[[j]]
    cgp   <- cell_gps[[j]]
    avail <- max(0, width - h_pad_in)

    # Header
    hdr_label <- cs$label %||% ""
    if (isTRUE(cs$wrap) && nzchar(hdr_label)) {
      hdr_label <- .wrap_string(hdr_label, avail, hdr_gp, breaks)
    }
    h_nlines <- max(1L, length(strsplit(hdr_label, "\n", fixed = TRUE)[[1L]]))
    h_grob   <- grid::textGrob(hdr_label, gp = hdr_gp)
    h_g      <- .height_in(grid::grobHeight(h_grob))
    h_l      <- h_nlines * .height_in(grid::stringHeight("M"))
    hdr_extra <- if (h_nlines > 1L) wrap_extra_pad_in else 0
    header_h <- max(h_g, h_l) + hdr_extra

    # Cells - dedupe to amortise grob measurement cost across repeats.
    strs <- cell_strs_list[[j]]
    unique_strs <- unique(strs)
    h_map <- vapply(unique_strs, function(s) {
      disp <- if (isTRUE(cs$wrap) && nzchar(s)) {
        .wrap_string(s, avail, cgp, breaks)
      } else s
      nl <- max(1L, length(strsplit(disp, "\n", fixed = TRUE)[[1L]]))
      g  <- grid::textGrob(disp, gp = cgp)
      hg <- .height_in(grid::grobHeight(g))
      hl <- nl * .height_in(grid::stringHeight("M"))
      ex <- if (nl > 1L) wrap_extra_pad_in else 0
      max(hg, hl) + ex
    }, numeric(1L))
    names(h_map) <- unique_strs
    cell_h <- as.numeric(h_map[strs])

    out <- list(header_h = header_h, cell_h = cell_h)
    assign(key, out, envir = cache)
    out
  }

  # Estimate total table height (header_row_h + sum of row heights).
  # v_pad_in is added once per row and once for the header, since every
  # cell in a row contributes the same v_pad.
  estimate_total <- function(w) {
    per_col <- lapply(seq_along(w), function(j) measure_col(j, w[[j]]))
    hdr_h   <- max(vapply(per_col, function(x) x$header_h, numeric(1L))) +
                v_pad_in
    cell_h_mat <- do.call(cbind,
                          lapply(per_col, function(x) x$cell_h))
    if (is.null(dim(cell_h_mat))) {
      # Single row: cbind of length-1 numeric vectors gives a 1xN matrix
      # but lapply across rows in a column-of-1 case yields 1-vectors.
      # Defensive reshape so apply() works.
      cell_h_mat <- matrix(cell_h_mat, nrow = 1L)
    }
    row_h_vec <- apply(cell_h_mat, 1L, max) + v_pad_in
    hdr_h + sum(row_h_vec)
  }

  current_h <- estimate_total(widths_in)
  start_t   <- Sys.time()

  eligible_idx <- which(wrap_eligible)

  for (iter in seq_len(max_iter)) {
    if (as.numeric(difftime(Sys.time(), start_t, units = "secs")) >
        budget_seconds) break

    # Identify the row with the maximum cell height (across all columns).
    per_col <- lapply(seq_along(widths_in),
                      function(j) measure_col(j, widths_in[[j]]))
    cell_h_mat <- do.call(cbind,
                          lapply(per_col, function(x) x$cell_h))
    if (is.null(dim(cell_h_mat))) cell_h_mat <- matrix(cell_h_mat, nrow = 1L)
    row_h_vec <- apply(cell_h_mat, 1L, max)
    if (length(row_h_vec) == 0L) break
    worst_row <- which.max(row_h_vec)
    row_cells <- cell_h_mat[worst_row, ]

    # Bottleneck = the wrap-eligible column whose cell drives the row max.
    eligible_in_row <- intersect(eligible_idx, which(row_cells > 0))
    if (length(eligible_in_row) == 0L) break
    cell_in_row     <- row_cells[eligible_in_row]
    bottleneck      <- eligible_in_row[which.max(cell_in_row)]

    # Slack = the wrap-eligible column with the SHORTEST cell in this row
    # (the column whose cell is most likely to absorb wrapping if narrowed).
    slack_candidates <- setdiff(eligible_idx, bottleneck)
    if (length(slack_candidates) == 0L) break
    slack_cells <- row_cells[slack_candidates]
    slack <- slack_candidates[which.min(slack_cells)]

    # Constraint check: bottleneck must have headroom; slack must have
    # room to give.
    headroom_b <- natural[[bottleneck]] - widths_in[[bottleneck]]
    give_room_s <- widths_in[[slack]] - floors[[slack]]
    if (headroom_b <= eps || give_room_s <= eps) break

    best_h <- current_h
    best_w <- NULL
    for (delta in c(0.5, 0.25, 0.1, 0.05)) {
      d <- min(delta, headroom_b, give_room_s)
      if (d <= eps) next
      new_w <- widths_in
      new_w[[slack]]      <- new_w[[slack]]      - d
      new_w[[bottleneck]] <- new_w[[bottleneck]] + d
      new_h <- estimate_total(new_w)
      if (new_h < best_h - eps) {
        best_h <- new_h
        best_w <- new_w
      }
    }

    if (is.null(best_w)) break
    widths_in <- best_w
    current_h <- best_h
  }

  widths_in
}
