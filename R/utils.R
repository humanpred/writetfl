# utils.R — Validation, coercion, and page argument building

#' Validate the file argument to export_fig_as_pdf
#' @keywords internal
validate_file_arg <- function(file) {
  if (!is.character(file) || length(file) != 1 || !grepl("\\.pdf$", file)) {
    rlang::abort("file must be a single character string ending in '.pdf'")
  }
  invisible(NULL)
}

#' Coerce x to a list of page specification lists
#'
#' @param x A ggplot object or a list of page spec lists.
#' @return A list of page spec lists, each with at least a `figure` element.
#' @keywords internal
coerce_x_to_pagelist <- function(x) {
  if (inherits(x, "ggplot")) {
    return(list(list(figure = x)))
  }
  if (!is.list(x)) {
    rlang::abort("x must be a ggplot object or a list of page specification lists")
  }
  for (i in seq_along(x)) {
    pg <- x[[i]]
    if (!is.list(pg) || is.null(pg$figure)) {
      rlang::abort(paste0("x[[", i, "]] must contain a 'figure' element"))
    }
    if (!inherits(pg$figure, "ggplot")) {
      rlang::abort("x$figure must be a ggplot object (other types not yet supported)")
    }
  }
  x
}

#' Build merged argument list for a single page
#'
#' Merges page list elements, dots, and page_num with correct precedence:
#' `x[[i]]` > dots > page_num fills footer_right only if absent.
#'
#' @param page_list Named list for this page (from `x[[i]]`).
#' @param dots List of arguments from ... in export_fig_as_pdf.
#' @param page_num Glue template string or NULL.
#' @param i Current page index.
#' @param n Total page count.
#' @return Named list of arguments ready for do.call(export_figpage_to_pdf, .)
#' @keywords internal
#' @importFrom utils modifyList
build_page_args <- function(page_list, dots, page_num, i, n) {
  pn_text <- if (!is.null(page_num)) {
    as.character(glue::glue_data(list(i = i, n = n), page_num))
  }

  # page_list wins over dots (modifyList(x, val) updates x with val, so val wins)
  args <- modifyList(dots, page_list)

  if (is.null(args$footer_right) && !is.null(pn_text)) {
    args$footer_right <- pn_text
  }

  args
}
