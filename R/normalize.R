# normalize.R — Input normalization helpers
# See ARCHITECTURE.md for full contracts.

#' Normalize text input to a single string with line count
#'
#' @param x NULL, a single character string, or a character vector.
#' @return A list with elements `text` (single string or NULL) and
#'   `nlines` (integer).
#' @keywords internal
normalize_text <- function(x) {
  if (is.null(x) || (is.character(x) && length(x) == 0L)) {
    return(list(text = NULL, nlines = 0L))
  }
  text <- paste(x, collapse = "\n")
  # strsplit("", "\n") returns character(0) so guard for empty string
  nlines <- if (nchar(text) == 0L) 1L else length(strsplit(text, "\n", fixed = TRUE)[[1]])
  list(text = text, nlines = as.integer(nlines))
}

#' Word-wrap a normalized text to fit within a given width
#'
#' Takes a normalized text list (from [normalize_text()]) and wraps it to
#' fit within `width_in` inches using greedy line-breaking. Returns a new
#' normalized text list with updated `text` and `nlines`.
#'
#' Must be called while a viewport with the target font metrics is active.
#'
#' @param norm Output of [normalize_text()].
#' @param gp Resolved `gpar()` for this text element.
#' @param width_in Available width in inches.
#' @return A list with `$text` (wrapped string) and `$nlines` (updated count).
#' @keywords internal
wrap_normalized_text <- function(norm, gp, width_in) {
  if (is.null(norm$text)) return(norm)
  wrapped <- .wrap_text(norm$text, width_in, gp)
  normalize_text(wrapped)
}

#' Normalize rule specification to FALSE or a grob
#'
#' @param x FALSE, TRUE, numeric in (0,1], or a grob.
#'   A `linesGrob` is the typical choice, but any grob is accepted and will be
#'   drawn as-is (centered vertically in the padding gap).
#' @return FALSE or a grob.
#' @keywords internal
normalize_rule <- function(x) {
  if (isFALSE(x)) {
    return(FALSE)
  }

  if (isTRUE(x)) {
    return(grid::linesGrob(
      x    = grid::unit(c(0, 1), "npc"),
      y    = grid::unit(c(0.5, 0.5), "npc"),
      name = "lines_rule"
    ))
  }

  if (is.numeric(x) && length(x) == 1L) {
    if (x <= 0 || x > 1) {
      rlang::abort("normalize_rule: numeric value must be in (0, 1]")
    }
    w <- x
    return(grid::linesGrob(
      x    = grid::unit(c((1 - w) / 2, (1 + w) / 2), "npc"),
      y    = grid::unit(c(0.5, 0.5), "npc"),
      name = "lines_rule"
    ))
  }

  if (inherits(x, "grob")) {
    return(x)
  }

  rlang::abort(
    "normalize_rule: x must be FALSE, TRUE, a numeric in (0, 1], or a grob"
  )
}
