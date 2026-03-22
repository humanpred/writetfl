# measure.R — Grob measurement helpers
# All functions MUST be called while the target viewport is active.
# See ARCHITECTURE.md for full contracts.

#' Measure grob height conservatively (primary + nlines fallback)
#'
#' @param grob A grob object, or NULL.
#' @param nlines Integer line count from normalize_text().
#' @return Numeric height in inches. Returns 0 if grob is NULL.
#' @keywords internal
measure_grob_height <- function(grob, nlines) {
  if (is.null(grob)) return(0)
  primary  <- grid::convertHeight(grid::grobHeight(grob), "inches", valueOnly = TRUE)
  fallback <- nlines * grid::convertHeight(grid::stringHeight("M"), "inches", valueOnly = TRUE)
  max(primary, fallback)
}

#' Measure grob width in inches. Returns 0 if grob is NULL.
#' @keywords internal
measure_grob_width <- function(grob) {
  if (is.null(grob)) return(0)
  grid::convertWidth(grid::grobWidth(grob), "inches", valueOnly = TRUE)
}

#' Measure heights of all five sections
#'
#' Header and footer heights are the MAX of their left/center/right grobs,
#' since all three occupy the same row. Called while outer_vp is active.
#'
#' @param header_grobs Named list: left, center, right grobs (or NULL).
#' @param caption_grob A grob or NULL.
#' @param footnote_grob A grob or NULL.
#' @param footer_grobs Named list: left, center, right grobs (or NULL).
#' @param norm_texts Named list of normalize_text() outputs for all 8 elements.
#' @return Named list: header, caption, footnote, footer (numeric inches).
#' @keywords internal
measure_section_heights <- function(header_grobs, caption_grob, footnote_grob,
                                    footer_grobs, norm_texts) {
  header_h <- max(
    measure_grob_height(header_grobs$header_left,   norm_texts$header_left$nlines),
    measure_grob_height(header_grobs$header_center, norm_texts$header_center$nlines),
    measure_grob_height(header_grobs$header_right,  norm_texts$header_right$nlines)
  )

  caption_h  <- measure_grob_height(caption_grob,  norm_texts$caption$nlines)
  footnote_h <- measure_grob_height(footnote_grob, norm_texts$footnote$nlines)

  footer_h <- max(
    measure_grob_height(footer_grobs$footer_left,   norm_texts$footer_left$nlines),
    measure_grob_height(footer_grobs$footer_center, norm_texts$footer_center$nlines),
    measure_grob_height(footer_grobs$footer_right,  norm_texts$footer_right$nlines)
  )

  list(header = header_h, caption = caption_h,
       footnote = footnote_h, footer = footer_h)
}

#' Measure widths of header left/center/right grobs
#'
#' Returns NULL for absent (NULL) grobs so overlap detection can distinguish
#' absent from zero-width.
#'
#' @param grobs Named list from build_section_grobs() — expects header_left,
#'   header_center, header_right.
#' @return Named list: left, center, right (numeric inches or NULL).
#' @keywords internal
measure_header_widths <- function(grobs) {
  list(
    left   = if (!is.null(grobs$header_left))   measure_grob_width(grobs$header_left)   else NULL,
    center = if (!is.null(grobs$header_center)) measure_grob_width(grobs$header_center) else NULL,
    right  = if (!is.null(grobs$header_right))  measure_grob_width(grobs$header_right)  else NULL
  )
}

#' Measure widths of footer left/center/right grobs
#'
#' @param grobs Named list from build_section_grobs() — expects footer_left,
#'   footer_center, footer_right.
#' @return Named list: left, center, right (numeric inches or NULL).
#' @keywords internal
measure_footer_widths <- function(grobs) {
  list(
    left   = if (!is.null(grobs$footer_left))   measure_grob_width(grobs$footer_left)   else NULL,
    center = if (!is.null(grobs$footer_center)) measure_grob_width(grobs$footer_center) else NULL,
    right  = if (!is.null(grobs$footer_right))  measure_grob_width(grobs$footer_right)  else NULL
  )
}
