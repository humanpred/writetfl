# ggtibble.R — S3 method and conversion for ggtibble objects
#
# Functions:
#   export_tfl.ggtibble()    — S3 method dispatched by export_tfl()
#   ggtibble_to_pagelist()   — convert ggtibble rows to page spec lists

#' @export
export_tfl.ggtibble <- function(
  x,
  file             = NULL,
  pg_width         = 11,
  pg_height        = 8.5,
  page_num         = "Page {i} of {n}",
  preview          = FALSE,
  sub_tfl          = NULL,
  sub_tfl_sep      = ": ",
  sub_tfl_collapse = "; ",
  sub_tfl_prefix   = "\n",
  ...
) {
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  x <- ggtibble_to_pagelist(x, sub_tfl = sub_tfl, sub_tfl_sep = sub_tfl_sep,
                            sub_tfl_collapse = sub_tfl_collapse,
                            sub_tfl_prefix = sub_tfl_prefix)
  .export_tfl_pages(x, file, pg_width, pg_height, page_num, preview, dots)
}

# Page-spec arg names recognised on a ggtibble row.
.ggtibble_page_arg_names <- c(
  "caption", "footnote",
  "header_left", "header_center", "header_right",
  "footer_left", "footer_center", "footer_right"
)

# Build one page spec from a single ggtibble row.
#' @keywords internal
.ggtibble_row_pagespec <- function(i, x, present_args, sub_tfl,
                                    sub_tfl_sep, sub_tfl_collapse,
                                    sub_tfl_prefix) {
  # Extract the ggplot from the figure cell. gglist[[i]] returns the ggplot
  # directly; for plain list columns, unwrap one level if needed.
  fig <- x$figure[[i]]
  if (!inherits(fig, "gg") && is.list(fig)) fig <- fig[[1L]]
  spec <- list(content = fig)
  for (col in present_args) {
    spec[[col]] <- x[[col]][[i]]
  }
  if (!is.null(sub_tfl)) {
    pairs <- vapply(sub_tfl, .format_ggtibble_sub_tfl_pair,
                    character(1L), x = x, i = i, sep = sub_tfl_sep)
    suffix <- paste(pairs, collapse = sub_tfl_collapse)
    spec$caption <- .apply_sub_tfl_caption(spec$caption, suffix,
                                           sub_tfl_prefix)
  }
  spec
}

#' Convert a ggtibble object to a list of page specification lists
#'
#' Each row of the ggtibble becomes one page spec. The `figure` column
#' provides the content (ggplot). Any columns whose names match
#' [export_tfl_page()] text arguments are used as per-page values. When
#' `sub_tfl` is supplied, those columns' values are appended to each row's
#' caption.
#'
#' @param x A `ggtibble` object.
#' @param sub_tfl Character vector of column names in `x`, or `NULL`.
#' @param sub_tfl_sep,sub_tfl_collapse,sub_tfl_prefix Formatting controls for
#'   the appended `label: value` suffix. See [tfl_table()].
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
ggtibble_to_pagelist <- function(x, sub_tfl = NULL, sub_tfl_sep = ": ",
                                 sub_tfl_collapse = "; ",
                                 sub_tfl_prefix = "\n") {
  present_args <- intersect(.ggtibble_page_arg_names, names(x))

  if (!is.null(sub_tfl)) {
    if (!is.character(sub_tfl) || length(sub_tfl) == 0L ||
        anyNA(sub_tfl) || any(!nzchar(sub_tfl))) {
      rlang::abort("`sub_tfl` must be NULL or a non-empty character vector.")
    }
    bad <- setdiff(sub_tfl, names(x))
    if (length(bad) > 0L) {
      rlang::abort(paste0(
        "`sub_tfl` columns not found in the ggtibble: ",
        paste(bad, collapse = ", ")
      ))
    }
    checkmate::assert_character(sub_tfl_sep,      len = 1L,
                                any.missing = FALSE,
                                .var.name = "sub_tfl_sep")
    checkmate::assert_character(sub_tfl_collapse, len = 1L,
                                any.missing = FALSE,
                                .var.name = "sub_tfl_collapse")
    checkmate::assert_character(sub_tfl_prefix,   len = 1L,
                                any.missing = FALSE,
                                .var.name = "sub_tfl_prefix")
  }

  lapply(seq_len(nrow(x)), .ggtibble_row_pagespec,
         x = x, present_args = present_args, sub_tfl = sub_tfl,
         sub_tfl_sep = sub_tfl_sep, sub_tfl_collapse = sub_tfl_collapse,
         sub_tfl_prefix = sub_tfl_prefix)
}
