#' Export a list of TFLs to a multi-page PDF
#'
#' @description
#' Opens a PDF device, renders each page using [writetfl::export_tfl_page()], and
#' closes the device. Guarantees device closure via `on.exit()` even if an
#' error occurs during rendering.
#'
#' @param x A single `ggplot` object, a grid grob (e.g. from
#'   `gt::as_gtable()` or `gridExtra::tableGrob()`), a [tfl_table()] object,
#'   or a named list of page specifications. Each page specification is a list
#'   with a required `content` element (a `ggplot` or grob) and optional
#'   elements corresponding to the text arguments of
#'   [writetfl::export_tfl_page()]: `header_left`, `header_center`,
#'   `header_right`, `caption`, `footnote`, `footer_left`, `footer_center`,
#'   `footer_right`. Per-page list elements take precedence over values
#'   supplied via `...`.
#'
#'   When `x` is a [tfl_table()] object, pagination and grob construction are
#'   performed automatically. Page layout arguments (`pg_width`, `pg_height`,
#'   and any arguments in `...` such as `margins`, `padding`, and annotations)
#'   are used both to compute available space and to render each page.
#' @param file Path to the output PDF file. Must be a single character string
#'   ending in `".pdf"`.
#' @param pg_width Page width in inches.
#' @param pg_height Page height in inches.
#' @param page_num A [glue::glue()] specification for automatic page numbering,
#'   where `{i}` is the current page number and `{n}` is the total number of
#'   pages. Set to `NULL` to disable.
#' @param ... Additional arguments passed to [writetfl::export_tfl_page()].
#'   These serve as defaults for all pages and are overridden by per-page
#'   list elements in `x`.
#'
#' @return The normalized absolute path to the PDF file, returned invisibly.
#'
#' @examples
#' \dontrun{
#' library(ggplot2)
#'
#' # Single plot
#' p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
#' export_tfl(p, "single.pdf")
#'
#' # Multiple plots with per-page captions
#' plots <- list(
#'   list(content = p, caption = "Weight vs MPG"),
#'   list(content = ggplot(mtcars, aes(hp, mpg)) + geom_point(),
#'        caption = "Horsepower vs MPG")
#' )
#' export_tfl(plots, "report.pdf",
#'   header_left  = "My Report",
#'   header_right = format(Sys.Date())
#' )
#' }
#'
#' @seealso [writetfl::export_tfl_page()] for single-page layout control.
#' @importFrom glue glue
#' @importFrom rlang abort
#' @export
export_tfl <- function(
  x,
  file,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  ...
) {
  # Validate and coerce inputs before opening the device
  validate_file_arg(file)
  dots <- list(...)

  if (inherits(x, "tfl_table")) {
    # Deferred pagination: convert tfl_table to page list with full layout context
    x <- tfl_table_to_pagelist(x, pg_width = pg_width, pg_height = pg_height,
                                dots = dots, page_num = page_num)
  } else {
    x <- coerce_x_to_pagelist(x)
  }

  n    <- length(x)

  grDevices::pdf(file, width = pg_width, height = pg_height)
  on.exit(grDevices::dev.off(), add = TRUE)

  for (i in seq_along(x)) {
    # Merge dots-level defaults with page-specific overrides (page_list wins)
    page_args <- build_page_args(x[[i]], dots, page_num, i, n)
    # Remove keys that belong in 'x' (the page spec list), not as named args
    # content, and any page-list-only keys are already in x[[i]]
    page_args$content <- NULL
    page_args$page_i  <- i
    do.call(export_tfl_page, c(list(x = x[[i]]), page_args))
  }

  invisible(normalizePath(file, mustWork = FALSE))
}
