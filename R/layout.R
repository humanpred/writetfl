# layout.R — Content height/width computation and validation

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

# Shared dispatch for width-overflow events.  Either appends `msg` to `errors`
# (when `overflow_action == "error"`) or emits an immediate rlang::warn() (when
# `"warn"`) and returns `errors` unchanged.  Every overflow message ends with
# the diagnostic-mode hint so users always see the escape hatch.
.overflow_signal <- function(msg, overflow_action, errors) {
  msg <- paste0(
    msg,
    "\n  Set `overflow_action = \"warn\"` to convert this error to a ",
    "warning and still produce output for diagnosis."
  )
  if (identical(overflow_action, "warn")) {
    rlang::warn(msg)
    errors
  } else {
    c(errors, msg)
  }
}

#' Check content width against an upper bound and signal if too wide
#'
#' Mirrors [check_content_height()] but is a maximum-ceiling check rather than
#' a minimum-floor check, and accepts an `overflow_action` knob that downgrades
#' the error to a warning so output can still be produced for diagnosis (see
#' issue #30).
#'
#' @param content_w_in Natural width of the content in inches.
#' @param vp_width_in Available content viewport width in inches.
#' @param overflow_action One of `"error"` (default) or `"warn"`.
#' @param errors Character vector to append to (when action is `"error"`).
#' @param what Label for the source of the width (e.g. `"Content"`,
#'   `"Column 'x'"`, `"Total column width"`).
#' @return Updated `errors` character vector.
#' @keywords internal
check_content_width <- function(content_w_in, vp_width_in, overflow_action,
                                errors, what = "Content") {
  if (content_w_in > vp_width_in + 1e-6) {
    msg <- sprintf(
      "%s width (%.4g in) exceeds available content width (%.4g in)",
      what, content_w_in, vp_width_in
    )
    errors <- .overflow_signal(msg, overflow_action, errors)
  }
  errors
}
