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

  tokens   <- vector("list", n)        # over-allocate; trim at end
  k        <- 0L
  cur_buf  <- character(n)
  cur_n    <- 0L
  pending  <- ""                       # lead for the next emitted token

  flush <- function() {
    if (cur_n > 0L) {
      k <<- k + 1L
      tokens[[k]] <<- list(
        text = paste(cur_buf[seq_len(cur_n)], collapse = ""),
        lead = pending
      )
      cur_n   <<- 0L
      pending <<- ""
    }
  }

  for (i in seq_len(n)) {
    ch <- chars[[i]]
    if (length(drop_chars) > 0L && ch %in% drop_chars) {
      flush()
      pending <- ch
    } else if (length(keep_chars) > 0L && ch %in% keep_chars) {
      cur_n          <- cur_n + 1L
      cur_buf[cur_n] <- ch
      flush()
      pending <- ""
    } else {
      cur_n          <- cur_n + 1L
      cur_buf[cur_n] <- ch
    }
  }
  flush()

  if (k == 0L) list() else tokens[seq_len(k)]
}

# ---------------------------------------------------------------------------
# .wrap_string() - wrap one string to fit a width
# ---------------------------------------------------------------------------

# Width of a string under the active viewport's font context, in inches.
.measure_text_width_in <- function(s, gp) {
  if (!nzchar(s)) return(0)
  .width_in(grid::grobWidth(grid::textGrob(s, gp = gp)))
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
#'
#' @return A single character string, possibly with `\n` inserted at break
#'   points.
#'
#' @keywords internal
.wrap_string <- function(text, available_w_in, gp,
                         breaks = wrap_breaks_default()) {
  if (is.null(text) || !nzchar(text)) return(text)
  if (is.null(breaks)) breaks <- wrap_breaks_default()

  paragraphs <- strsplit(text, "\n", fixed = TRUE)[[1L]]
  wrapped    <- vapply(paragraphs, function(para) {
    if (!nzchar(para)) return("")
    .wrap_paragraph(para, available_w_in, gp, breaks)
  }, character(1L))
  paste(wrapped, collapse = "\n")
}

.wrap_paragraph <- function(para, available_w_in, gp, breaks) {
  tokens <- .tokenize_for_wrap(para, breaks)
  if (length(tokens) == 0L) return("")

  lines        <- character(0L)
  current_line <- ""

  for (tok in tokens) {
    if (!nzchar(current_line)) {
      current_line <- tok$text
      next
    }
    cand <- paste0(current_line, tok$lead, tok$text)
    if (.measure_text_width_in(cand, gp) <= available_w_in + 1e-6) {
      current_line <- cand
    } else {
      lines        <- c(lines, current_line)
      current_line <- tok$text
    }
  }
  if (nzchar(current_line)) lines <- c(lines, current_line)
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
#' needed to render its longest single token.
#'
#' @keywords internal
.column_min_token_width_in <- function(strings, gp, breaks) {
  if (length(strings) == 0L) return(0)
  max(vapply(strings, function(s) {
    if (!nzchar(s)) return(0)
    paragraphs <- strsplit(s, "\n", fixed = TRUE)[[1L]]
    max(vapply(paragraphs, function(p) {
      tokens <- .tokenize_for_wrap(p, breaks)
      if (length(tokens) == 0L) return(0)
      max(vapply(tokens, function(tok) {
        .measure_text_width_in(tok$text, gp)
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

  scratch_file <- tempfile(fileext = ".pdf")
  grDevices::pdf(scratch_file, width = pg_width, height = pg_height)
  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)
  on.exit({
    grid::popViewport()
    grDevices::dev.off()
    unlink(scratch_file)
  }, add = TRUE)

  # Compute per-column floors (only meaningful for wrap-eligible cols).
  floors <- widths_in
  for (j in which(wrap_eligible)) {
    cs      <- resolved_cols[[j]]
    cell_gp <- .gp_with_lineheight(
      .resolve_table_cell_gp(tbl$gp, cs$is_group_col), tbl$line_height
    )
    strings <- .collect_col_strings(data[[cs$col]], cs$label, na_str, max_rows)
    token_w <- .column_min_token_width_in(strings, cell_gp, breaks)
    floors[[j]] <- max(min_in, token_w + h_pad_in)
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
