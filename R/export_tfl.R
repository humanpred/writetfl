#' Export a list of TFLs to a multi-page PDF
#'
#' @description
#' Opens a PDF device, renders each page using [writetfl::export_tfl_page()], and
#' closes the device. Guarantees device closure via `on.exit()` even if an
#' error occurs during rendering.
#'
#' When `preview` is not `FALSE`, no PDF is written. Instead the selected pages
#' are drawn to the currently open graphics device (useful in RStudio, Positron,
#' or knitr chunks) and returned as a list of grid grobs.
#'
#' @param x A single `ggplot` object, a grid grob (e.g. from
#'   `gt::as_gtable()` or `gridExtra::tableGrob()`), a [tfl_table()] object,
#'   a `ggtibble` object (from the \pkg{ggtibble} package),
#'   a `gt_tbl` object (from the \pkg{gt} package),
#'   a list of `gt_tbl` objects,
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
#'
#'   When `x` is a `ggtibble` object, each row becomes a page. The `figure`
#'   column provides the content; any columns whose names match
#'   `export_tfl_page()` text arguments (`caption`, `footnote`,
#'   `header_left`, etc.) are used as per-page values. Other columns are
#'   ignored.
#'
#'   When `x` is a `gt_tbl` object, the title and subtitle are extracted as
#'   the caption, source notes and footnotes are extracted as the footnote,
#'   and the table body is rendered as a grid grob via [gt::as_gtable()].
#'   A list of `gt_tbl` objects produces one page (or more, with pagination)
#'   per table.
#'
#'   When `x` is a `VTableTree` object (from the \pkg{rtables} package), the
#'   main title and subtitles are extracted as the caption, and main footer
#'   and provenance footer are extracted as the footnote. The table is
#'   rendered as monospace text via `toString()` and wrapped in a grid
#'   `textGrob`. Pagination uses rtables' built-in `paginate_table()`.
#'   A list of `VTableTree` objects produces one page (or more, with
#'   pagination) per table.
#'
#'   When `x` is a `flextable` object (from the \pkg{flextable} package),
#'   the caption (from [flextable::set_caption()]) is extracted as the
#'   caption, and footer rows (from [flextable::footnote()] or
#'   [flextable::add_footer_lines()]) are extracted as the footnote. The
#'   table is rendered via [flextable::gen_grob()]. A list of `flextable`
#'   objects produces one page (or more, with pagination) per table.
#'
#'   When `x` is a `table1` object (from the \pkg{table1} package), the
#'   caption and footnote are extracted from the table1 object's internal
#'   structure. The table is converted to a flextable via [table1::t1flex()],
#'   preserving column labels, bold variable names, and indented summary
#'   statistics. Pagination is group-aware: page breaks fall between
#'   variable groups (label + summary rows) rather than splitting a group
#'   mid-way. A list of `table1` objects produces one page (or more, with
#'   pagination) per table.
#' @param file Path to the output PDF file. Must be a single character string
#'   ending in `".pdf"`. Not required when `preview` is not `FALSE`.
#' @param pg_width Page width in inches.
#' @param pg_height Page height in inches.
#' @param page_num A [glue::glue()] specification for automatic page numbering,
#'   where `{i}` is the current page number and `{n}` is the total number of
#'   pages. Set to `NULL` to disable.
#' @param preview Controls preview rendering instead of PDF output:
#'   - `FALSE` (default): write to `file` as normal.
#'   - `TRUE`: render all pages to the current graphics device.
#'   - An integer vector: render only the specified page numbers (e.g.
#'     `preview = c(1, 3)` renders pages 1 and 3).
#'
#'   In preview mode each page is drawn via `grid::grid.newpage()` (so knitr
#'   captures it as an inline graphic). Returns `NULL` invisibly.
#' @inheritDotParams export_tfl_page -x -page_i -preview
#' @details
#' Arguments forwarded via `...` serve as defaults for all pages and are
#' overridden by per-page list elements in `x`.
#'
#' @return
#' - Normal mode (`preview = FALSE`): the normalized absolute path to the PDF
#'   file, returned invisibly.
#' - Preview mode: `NULL`, invisibly.
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
#'
#' # Preview the first two pages without writing a file
#' export_tfl(plots, preview = c(1, 2),
#'   header_left = "My Report"
#' )
#' }
#'
#' @seealso [writetfl::export_tfl_page()] for single-page layout control.
#' @importFrom glue glue
#' @importFrom rlang abort
#' @export
export_tfl <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  UseMethod("export_tfl")
}

#' @export
export_tfl.default <- function(
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
  md <- .open_metric_device(file, pg_width, pg_height, preview)
  x <- coerce_x_to_pagelist(x)
  if (!isFALSE(preview)) .close_metric_device(md)
  .export_tfl_pages(x, file, pg_width, pg_height, page_num, preview, dots,
                    pdf_already_open = TRUE)
}

#' @export
export_tfl.tfl_table <- function(
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

  # Open the metric device BEFORE pagination so measurement runs on the
  # same device the drawing phase will use (normal mode) or a transient
  # pdf(NULL) with matching settings (preview mode).  The helper
  # registers on.exit on THIS frame, so a mid-pagination or mid-drawing
  # error still closes the device cleanly.
  md <- .open_metric_device(file, pg_width, pg_height, preview)

  # Cross-phase text-dimension cache.  Pagination populates it with
  # (width, height) per (gp_key, string).  In PDF mode (preview = FALSE),
  # pagination and drawing share `md$dev`, so cached values are
  # authoritative for the render pass without re-measurement.  In preview
  # mode, the user's render device differs from `md$dev`, so drawing
  # gets a fresh empty cache and falls back to per-cell measurement --
  # preserving today's preview behaviour exactly.
  pagination_cache <- new.env(hash = TRUE, parent = emptyenv())
  x <- tfl_table_to_pagelist(x, pg_width = pg_width, pg_height = pg_height,
                              dots = dots, page_num = page_num,
                              text_dim_cache = pagination_cache)

  drawing_cache <- if (isFALSE(preview)) pagination_cache else
    new.env(hash = TRUE, parent = emptyenv())

  # Attach the drawing cache to every tfl_table grob in the pagelist so
  # drawDetails can reach it.  Loops are O(n_pages); each assignment is
  # a reference copy, not a data copy.
  for (i in seq_along(x)) {
    if (inherits(x[[i]]$content, "tfl_table_grob")) {
      x[[i]]$content$text_dim_cache <- drawing_cache
    }
  }

  # Preview mode: close the transient pagination device so the user's
  # device is active for drawing.  The on.exit guard installed by
  # `.open_metric_device()` will see this device already closed (via
  # `.close_metric_device`'s idempotency check) and no-op.
  if (!isFALSE(preview)) .close_metric_device(md)

  .export_tfl_pages(x, file, pg_width, pg_height, page_num, preview, dots,
                    pdf_already_open = TRUE)
}

#' @export
export_tfl.list <- function(
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

  md <- .open_metric_device(file, pg_width, pg_height, preview)

  # Check if this is a list of gt_tbl objects
  all_gt <- length(x) > 0L &&
    all(vapply(x, inherits, logical(1L), "gt_tbl"))
  if (all_gt) {
    rlang::check_installed("gt", reason = "to export gt tables")
    pages <- unlist(lapply(x, gt_to_pagelist, pg_width, pg_height,
                          dots, page_num), recursive = FALSE)
  } else {
    # Check if this is a list of rtables VTableTree objects
    all_rtables <- length(x) > 0L &&
      all(vapply(x, inherits, logical(1L), "VTableTree"))
    if (all_rtables) {
      rlang::check_installed("rtables", reason = "to export rtables tables")
      pages <- unlist(lapply(x, rtables_to_pagelist, pg_width, pg_height,
                            dots, page_num), recursive = FALSE)
    } else {
      # Check if this is a list of flextable objects
      all_flextable <- length(x) > 0L &&
        all(vapply(x, inherits, logical(1L), "flextable"))
      if (all_flextable) {
        rlang::check_installed("flextable",
                               reason = "to export flextable tables")
        pages <- unlist(lapply(x, flextable_to_pagelist, pg_width, pg_height,
                              dots, page_num), recursive = FALSE)
      } else {
        # Check if this is a list of table1 objects
        all_table1 <- length(x) > 0L &&
          all(vapply(x, inherits, logical(1L), "table1"))
        if (all_table1) {
          rlang::check_installed("table1",
                                 reason = "to export table1 tables")
          rlang::check_installed("flextable",
                                 reason = "to export table1 tables")
          pages <- unlist(lapply(x, table1_to_pagelist, pg_width, pg_height,
                                dots, page_num), recursive = FALSE)
        } else {
          pages <- coerce_x_to_pagelist(x)
        }
      }
    }
  }
  if (!isFALSE(preview)) .close_metric_device(md)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots,
                    pdf_already_open = TRUE)
}


# ---------------------------------------------------------------------------
# Shared validation and page-rendering helpers
# ---------------------------------------------------------------------------

# Validate common export_tfl arguments
.validate_export_args <- function(page_num, preview, file) {
  if (!is.null(page_num)) {
    checkmate::assert_string(page_num, .var.name = "page_num")
  }
  if (isFALSE(preview)) {
    validate_file_arg(file)
  }
  invisible(NULL)
}

# Open the metric device for an export_tfl() call.  D-48 establishes
# that one device covers both pagination measurements and (in normal
# mode) drawing, rather than each measurement helper opening its own
# scratch device.
#
# Normal mode (`isFALSE(preview)`): opens `grDevices::pdf(file)` -- the
# final output PDF.  Pagination uses it for `convertWidth` / `grobWidth`
# resolution; subsequent drawing reuses the same device.
#
# Preview mode: opens a transient `grDevices::pdf(NULL)` so pagination
# uses identical PDF font metrics to normal mode (preserving today's
# pagination decisions).  The caller is responsible for invoking
# `.close_metric_device()` AFTER pagination so the user's pre-existing
# device becomes active again for drawing.
#
# Safety:
# * The helper registers an `on.exit()` handler on the CALLER's frame
#   (`envir`) so any error during pagination or drawing still closes
#   the device.  Without that, an interrupted run would leak the
#   device; running export_tfl() again would then open another and
#   eventually exhaust the per-session limit of 64.
# * `.close_metric_device()` is idempotent: calling it explicitly in
#   preview mode and then letting `on.exit` run is harmless because
#   the second call sees a different `dev.cur()` and no-ops.
#
# @keywords internal
.open_metric_device <- function(file, pg_width, pg_height, preview,
                                 envir = parent.frame()) {
  if (isFALSE(preview)) {
    grDevices::pdf(file, width = pg_width, height = pg_height)
  } else {
    grDevices::pdf(NULL, width = pg_width, height = pg_height)
  }
  dev <- grDevices::dev.cur()
  md  <- list(dev = dev)
  # Register on.exit on the caller's frame so the device closes even
  # if the caller errors out mid-execution.  bquote inlines `dev` so
  # the on.exit body does not need to reach back to `md`.
  do.call("on.exit",
          list(bquote({
            if (grDevices::dev.cur() == .(dev)) grDevices::dev.off()
          }), add = TRUE),
          envir = envir)
  md
}

# Close a metric device opened by `.open_metric_device()`.
#
# Idempotent: a second call (or a call when the device has already been
# closed by something else) is a no-op.  Idempotency matters because
# preview-mode callers close explicitly after pagination AND register
# the same close via the helper's `on.exit` handler.
#
# @keywords internal
.close_metric_device <- function(md) {
  if (!is.null(md$dev) && grDevices::dev.cur() == md$dev) {
    grDevices::dev.off()
  }
  invisible(NULL)
}

# Render a list of page specs to PDF or the current device.
#
# `pdf_already_open` signals that the CALLER has already opened the
# render device (via `.open_metric_device()`) and owns its lifecycle.
# In that case this function skips its own `pdf()` open / on.exit
# close and just iterates pages.  When the caller does not pass the
# flag (e.g. `export_tfl.default()` for ggplot pages), the legacy
# self-open path is preserved.
.export_tfl_pages <- function(pages, file, pg_width, pg_height,
                               page_num, preview, dots,
                               pdf_already_open = FALSE) {
  n <- length(pages)

  # ------------------------------------------------------------------
  # Preview mode: render selected pages to the current device
  # ------------------------------------------------------------------
  if (!isFALSE(preview)) {
    page_idx <- if (isTRUE(preview)) seq_len(n) else as.integer(preview)
    if (any(page_idx < 1L | page_idx > n)) {
      rlang::abort(paste0(
        "preview contains page indices out of range [1, ", n, "]."
      ))
    }
    for (j in seq_along(page_idx)) {
      i         <- page_idx[[j]]
      page_args <- build_page_args(pages[[i]], dots, page_num, i, n)
      page_args$content <- NULL
      page_args$page_i  <- i
      page_args$preview <- TRUE
      do.call(export_tfl_page, c(list(x = pages[[i]]), page_args))
    }
    return(invisible(NULL))
  }

  # ------------------------------------------------------------------
  # Normal mode: write PDF
  # ------------------------------------------------------------------
  if (!pdf_already_open) {
    grDevices::pdf(file, width = pg_width, height = pg_height)
    on.exit(grDevices::dev.off(), add = TRUE)
  }

  for (i in seq_along(pages)) {
    page_args <- build_page_args(pages[[i]], dots, page_num, i, n)
    page_args$content <- NULL
    page_args$page_i  <- i
    # The metric device (D-48) already opened page 1 during pagination, so
    # the first page draws onto it rather than advancing past it (which would
    # leave a blank leading page); later pages advance normally.
    page_args$newpage <- (i != 1L)
    do.call(export_tfl_page, c(list(x = pages[[i]]), page_args))
  }

  invisible(normalizePath(file, mustWork = FALSE))
}
