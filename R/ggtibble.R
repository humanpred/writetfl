# ggtibble.R — S3 method and conversion for ggtibble objects
#
# Functions:
#   export_tfl.ggtibble()    — S3 method dispatched by export_tfl()
#   ggtibble_to_pagelist()   — convert ggtibble rows to page spec lists

#' @export
export_tfl.ggtibble <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  x <- ggtibble_to_pagelist(x)
  .export_tfl_pages(x, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a ggtibble object to a list of page specification lists
#'
#' Each row of the ggtibble becomes one page spec. The `figure` column
#' provides the content (ggplot). Any columns whose names match
#' [export_tfl_page()] text arguments are used as per-page values.
#'
#' @param x A `ggtibble` object.
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
ggtibble_to_pagelist <- function(x) {
  # Column names that map to export_tfl_page() text arguments
  page_arg_names <- c(
    "caption", "footnote",
    "header_left", "header_center", "header_right",
    "footer_left", "footer_center", "footer_right"
  )
  present_args <- intersect(page_arg_names, names(x))

  lapply(seq_len(nrow(x)), function(i) {
    # Extract the ggplot from the figure cell.
    # gglist[[i]] returns the ggplot directly; for plain list columns,
    # unwrap one level if needed.
    fig <- x$figure[[i]]
    if (!inherits(fig, "gg") && is.list(fig)) fig <- fig[[1L]]
    spec <- list(content = fig)
    for (col in present_args) {
      spec[[col]] <- x[[col]][[i]]
    }
    spec
  })
}
