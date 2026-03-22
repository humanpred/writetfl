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
