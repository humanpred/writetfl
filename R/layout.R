# layout.R — Figure height computation and validation

#' Compute available figure height after subtracting all other sections
#'
#' @param vp_height_in Viewport (outer_vp) height in inches.
#' @param section_heights Named list: header, caption, footnote, footer (inches).
#' @param present Logical named vector: header, caption, figure, footnote, footer.
#' @param padding_in Padding height in inches.
#' @return Numeric figure height in inches.
#' @keywords internal
compute_figure_height <- function(vp_height_in, section_heights, present,
                                  padding_in) {
  # Number of padding gaps = (number of present sections) - 1
  # Any two present sections that are vertically adjacent (with only absent
  # sections between them) get exactly one padding gap.
  n_padding_gaps <- max(0L, sum(present) - 1L)

  fig_h <- vp_height_in -
    sum(unlist(section_heights)) -
    n_padding_gaps * padding_in

  fig_h
}

#' Check figure height against minimum and collect error if too short
#'
#' @param fig_h_in Computed figure height in inches.
#' @param min_figheight A unit object.
#' @param errors Character vector to append to.
#' @return Updated errors character vector.
#' @keywords internal
check_figure_height <- function(fig_h_in, min_figheight, errors) {
  min_in <- grid::convertHeight(min_figheight, "inches", valueOnly = TRUE)
  if (fig_h_in < min_in) {
    errors <- c(errors, sprintf(
      "Figure height (%.4g) is less than min_figheight (%.4g)",
      fig_h_in, min_in
    ))
  }
  errors
}
