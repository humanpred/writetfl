# overlap.R — Horizontal overlap detection
# See ARCHITECTURE.md for exact check logic and gap thresholds.

#' Check for horizontal overlap between left/center/right elements
#'
#' Checks for overlap within a single row (header or footer). Errors are
#' collected and returned; near-miss warnings are issued immediately via
#' rlang::warn().
#'
#' @param widths Named list with elements `left`, `center`, `right` (numeric
#'   inches, or NULL when element is absent).
#' @param vp_width_in Viewport width in inches.
#' @param overlap_warn_mm Near-miss threshold in mm. NULL skips all detection.
#' @param row_name Prefix used in error/warning messages ("header" or "footer").
#' @return Character vector of error messages (length 0 if no errors).
#' @keywords internal
check_overlap <- function(widths, vp_width_in, overlap_warn_mm = 2,
                          row_name = "header") {
  if (is.null(overlap_warn_mm)) return(character(0))

  errors       <- character(0)
  threshold_in <- overlap_warn_mm / 25.4

  left_w   <- widths$left
  center_w <- widths$center
  right_w  <- widths$right

  left_nm   <- paste0(row_name, "_left")
  center_nm <- paste0(row_name, "_center")
  right_nm  <- paste0(row_name, "_right")

  # Check left / center overlap
  if (!is.null(left_w) && !is.null(center_w)) {
    gap <- 0.5 * vp_width_in - left_w - center_w / 2
    if (gap < 0) {
      errors <- c(errors, sprintf(
        "%s and %s overlap (gap: %.2f mm)",
        left_nm, center_nm, gap * 25.4
      ))
    } else if (gap < threshold_in) {
      rlang::warn(sprintf(
        "%s and %s near-miss overlap (gap: %.2f mm)",
        left_nm, center_nm, gap * 25.4
      ))
    }
  }

  # Check right / center overlap
  if (!is.null(right_w) && !is.null(center_w)) {
    gap <- 0.5 * vp_width_in - right_w - center_w / 2
    if (gap < 0) {
      errors <- c(errors, sprintf(
        "%s and %s overlap (gap: %.2f mm)",
        right_nm, center_nm, gap * 25.4
      ))
    } else if (gap < threshold_in) {
      rlang::warn(sprintf(
        "%s and %s near-miss overlap (gap: %.2f mm)",
        right_nm, center_nm, gap * 25.4
      ))
    }
  }

  # Check left / right overlap when center is absent
  if (!is.null(left_w) && !is.null(right_w) && is.null(center_w)) {
    gap <- vp_width_in - left_w - right_w
    if (gap < 0) {
      errors <- c(errors, sprintf(
        "%s and %s overlap (gap: %.2f mm)",
        left_nm, right_nm, gap * 25.4
      ))
    } else if (gap < threshold_in) {
      rlang::warn(sprintf(
        "%s and %s near-miss overlap (gap: %.2f mm)",
        left_nm, right_nm, gap * 25.4
      ))
    }
  }

  errors
}
