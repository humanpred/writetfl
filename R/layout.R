# layout.R — Content height computation and validation

#' Compute available content height after subtracting all other sections
#'
#' @param vp_height_in Viewport (outer_vp) height in inches.
#' @param section_heights Named list: header, caption, footnote, footer (inches).
#' @param present Logical named vector: header, caption, content, footnote, footer.
#' @param padding_in Padding height in inches.
#' @return Numeric content height in inches.
#' @keywords internal
compute_content_height <- function(vp_height_in, section_heights, present,
                                   padding_in) {
  # Number of padding gaps = (number of present sections) - 1
  # Any two present sections that are vertically adjacent (with only absent
  # sections between them) get exactly one padding gap.
  n_padding_gaps <- max(0L, sum(present) - 1L)

  content_h <- vp_height_in -
    sum(unlist(section_heights)) -
    n_padding_gaps * padding_in

  content_h
}

#' Check content height against minimum and collect error if too short
#'
#' @param content_h_in Computed content height in inches.
#' @param min_content_height A unit object.
#' @param errors Character vector to append to.
#' @return Updated errors character vector.
#' @keywords internal
check_content_height <- function(content_h_in, min_content_height, errors) {
  min_in <- .height_in(min_content_height)
  if (content_h_in < min_in) {
    errors <- c(errors, sprintf(
      "Content height (%.4g) is less than min_content_height (%.4g)",
      content_h_in, min_in
    ))
  }
  errors
}
