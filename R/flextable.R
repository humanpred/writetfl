# flextable.R — S3 method and conversion for flextable objects
#
# Functions:
#   export_tfl.flextable()              — S3 method dispatched by export_tfl()
#   flextable_to_pagelist()             — convert a flextable to a list of page specs
#   .extract_flextable_annotations()    — extract caption and footer-row footnotes
#   .clean_flextable()                  — remove footer rows from flextable
#   .flextable_content_height()         — compute available content height
#   .flextable_content_width()          — compute available content width
#   .flextable_grob_height()            — measure a flextableGrob height
#   .flextable_to_grob()                — render a flextable to a grob via gen_grob()
#   .paginate_flextable()               — greedy row pagination
#   .rebuild_flextable_subset()         — create a sub-flextable from row indices

#' @export
export_tfl.flextable <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  rlang::check_installed("flextable", reason = "to export flextable tables")
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  pages <- flextable_to_pagelist(x, pg_width, pg_height, dots, page_num)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a flextable object to a list of page specification lists
#'
#' Extracts caption and footer-row footnotes from the flextable, removes the
#' footer rows to avoid duplication, then renders via [flextable::gen_grob()].
#'
#' When the rendered table exceeds the available content height, rows are
#' split across multiple pages using greedy pagination.
#'
#' @param ft_obj A `flextable` object.
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional arguments from `...`.
#' @param page_num Glue template for page numbering (used for height calc).
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
flextable_to_pagelist <- function(ft_obj, pg_width = 11, pg_height = 8.5,
                                  dots = list(), page_num = "Page {i} of {n}") {
  annot   <- .extract_flextable_annotations(ft_obj)
  cleaned <- .clean_flextable(ft_obj)

  # Measure available content area
  content_h <- .flextable_content_height(pg_width, pg_height, dots, page_num,
                                         annot)
  content_w <- .flextable_content_width(pg_width, dots)

  # Convert to grob and measure height
  grob   <- .flextable_to_grob(cleaned, content_w)
  grob_h <- .flextable_grob_height(grob)

  # If the table fits on a single page, return immediately
  if (grob_h <= content_h) {
    page_spec <- list(content = grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    return(list(page_spec))
  }

  # Paginate: split rows across pages
  ft_pages <- .paginate_flextable(cleaned, content_h, content_w)

  lapply(ft_pages, function(ft_page) {
    page_grob <- .flextable_to_grob(ft_page, content_w)
    page_spec <- list(content = page_grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    page_spec
  })
}

#' Extract annotations from a flextable object
#'
#' Extracts caption from `set_caption()` and footnote text from footer rows
#' (added via `footnote()` or `add_footer_lines()`).
#'
#' @param ft_obj A `flextable` object.
#' @return A list with `$caption` (character or NULL) and `$footnote`
#'   (character or NULL).
#' @keywords internal
.extract_flextable_annotations <- function(ft_obj) {
  # Caption
  cap_val <- ft_obj$caption$value
  caption <- if (!is.null(cap_val) && nzchar(cap_val)) cap_val

  # Footnote: extract text from footer rows
  n_footer <- flextable::nrow_part(ft_obj, "footer")
  footnote <- NULL
  if (n_footer > 0L) {
    content_data <- ft_obj$footer$content$data
    fn_lines <- vapply(seq_len(n_footer), function(i) {
      # Each row's first column contains the text (footer lines span all cols)
      chunks <- content_data[[i, 1L]]
      paste(chunks$txt, collapse = "")
    }, character(1L))
    fn_lines <- fn_lines[nzchar(fn_lines)]
    if (length(fn_lines) > 0L) {
      footnote <- paste(fn_lines, collapse = "\n")
    }
  }

  list(caption = caption, footnote = footnote)
}

#' Remove footer rows from a flextable object
#'
#' Strips footer rows so that `gen_grob()` renders only the header and body.
#' Footer text has already been extracted into writetfl's footnote zone.
#'
#' @param ft_obj A `flextable` object.
#' @return A cleaned `flextable` object.
#' @keywords internal
.clean_flextable <- function(ft_obj) {
  n_footer <- flextable::nrow_part(ft_obj, "footer")
  if (n_footer > 0L) {
    ft_obj <- flextable::delete_rows(ft_obj, i = seq_len(n_footer),
                                     part = "footer")
  }
  ft_obj
}

#' Compute available content height for flextable pagination
#'
#' Reuses [compute_table_content_area()] to measure how much vertical space
#' the content gets after header, caption, footnote, and footer sections are
#' accounted for.
#'
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional page-layout arguments.
#' @param page_num Glue template for page numbering.
#' @param annot Annotation list from [.extract_flextable_annotations()].
#' @return Numeric scalar: available content height in inches.
#' @keywords internal
.flextable_content_height <- function(pg_width, pg_height, dots, page_num,
                                      annot) {
  .dot <- function(key) {
    if (!is.null(dots[[key]])) dots[[key]] else .tfl_page_defaults[[key]]
  }

  annot_args <- list(
    header_left   = dots$header_left,
    header_center = dots$header_center,
    header_right  = dots$header_right,
    caption       = annot$caption  %||% dots$caption,
    footnote      = annot$footnote %||% dots$footnote,
    footer_left   = dots$footer_left,
    footer_center = dots$footer_center,
    footer_right  = dots$footer_right
  )

  # Account for page_num in footer if footer_right is absent
  if (is.null(annot_args$footer_right) && !is.null(page_num)) {
    annot_args$footer_right <- "Page 1 of 1"
  }

  dims <- compute_table_content_area(
    pg_width, pg_height,
    .dot("margins"), .dot("padding"),
    .dot("header_rule"), .dot("footer_rule"),
    annot_args, .dot("gp"),
    .dot("caption_just"), .dot("footnote_just")
  )
  dims$height
}

#' Compute available content width
#'
#' @param pg_width Page width in inches.
#' @param dots Named list of additional page-layout arguments.
#' @return Numeric scalar: available content width in inches.
#' @keywords internal
.flextable_content_width <- function(pg_width, dots) {
  margins <- if (!is.null(dots$margins)) {
    dots$margins
  } else {
    .tfl_page_defaults$margins
  }
  margin_vals <- grid::convertWidth(margins, "inches", valueOnly = TRUE)
  # margins are c(top, right, bottom, left)
  pg_width - margin_vals[2] - margin_vals[4]
}

#' Measure a flextableGrob's height
#'
#' flextableGrob does not support standard `grobHeight()` measurement.
#' Instead, the total height is available from the grob's `ftpar$heights`
#' attribute, which contains per-row heights in inches.
#'
#' @param grob A `flextableGrob` from [flextable::gen_grob()].
#' @return Numeric scalar: grob height in inches.
#' @keywords internal
.flextable_grob_height <- function(grob) {
  sum(grob$ftpar$heights)
}

#' Render a flextable to a grob via gen_grob()
#'
#' Sets column widths proportionally to fit the available content width,
#' ensures a PDF-compatible font is used, then calls
#' [flextable::gen_grob()] with `fit = "width"` and top-left justification.
#'
#' @param ft_obj A `flextable` object.
#' @param content_w Available content width in inches.
#' @return A `flextableGrob` (inherits from `gTree`).
#' @keywords internal
.flextable_to_grob <- function(ft_obj, content_w) {
  # Scale column widths to fit available content width
  orig_widths <- ft_obj$body$colwidths
  total_w     <- sum(orig_widths)
  if (total_w > 0) {
    scale_factor <- content_w / total_w
    ft_obj <- flextable::width(ft_obj, width = orig_widths * scale_factor)
  }

  # Ensure a PDF-compatible font (flextable defaults to "Arial" which
  # does not work on the standard PDF device)
  ft_obj <- .flextable_set_pdf_font(ft_obj)

  flextable::gen_grob(ft_obj, fit = "width", just = c("left", "top"))
}

#' Set PDF-compatible font on a flextable
#'
#' Replaces any non-standard font families with `"Helvetica"` (a standard
#' PDF base font) to avoid "invalid font type" errors on the PDF device.
#'
#' @param ft_obj A `flextable` object.
#' @return The modified `flextable` object.
#' @keywords internal
.flextable_set_pdf_font <- function(ft_obj) {
  # Standard PDF base fonts
  pdf_fonts <- c("Helvetica", "Times", "Courier", "sans", "serif", "mono",
                 "Helvetica-Bold", "Helvetica-Oblique",
                 "Times-Roman", "Times-Bold", "Courier-Bold")
  defaults <- flextable::get_flextable_defaults()
  default_font <- defaults[["font.family"]]
  if (!is.null(default_font) && !(default_font %in% pdf_fonts)) {
    ft_obj <- flextable::font(ft_obj, fontname = "Helvetica", part = "all")
  }
  ft_obj
}

#' Greedy row pagination for flextable
#'
#' Incrementally adds body rows, measures the sub-table height, and splits
#' when a page would overflow.
#'
#' @param ft_obj A cleaned `flextable` (no footer rows).
#' @param content_h Available content height in inches.
#' @param content_w Available content width in inches.
#' @return A list of `flextable` objects (one per page).
#' @keywords internal
.paginate_flextable <- function(ft_obj, content_h, content_w) {
  n_body <- flextable::nrow_part(ft_obj, "body")

  pages        <- list()
  current_rows <- integer(0L)

  for (row_idx in seq_len(n_body)) {
    candidate_rows <- c(current_rows, row_idx)
    sub_ft   <- .rebuild_flextable_subset(ft_obj, candidate_rows)
    sub_grob <- .flextable_to_grob(sub_ft, content_w)
    h        <- .flextable_grob_height(sub_grob)

    if (h > content_h && length(current_rows) > 0L) {
      # Current row doesn't fit — finalize current page
      pages <- c(pages, list(.rebuild_flextable_subset(ft_obj, current_rows)))
      current_rows <- row_idx
    } else {
      current_rows <- candidate_rows
    }
  }
  if (length(current_rows) > 0L) {
    pages <- c(pages, list(.rebuild_flextable_subset(ft_obj, current_rows)))
  }

  pages
}

#' Rebuild a flextable from a row index subset
#'
#' Creates a new flextable from the subset of body rows, preserving the
#' header structure and column widths. Per-cell formatting applied via
#' `color()`, `bg()`, `bold()`, etc. is NOT preserved.
#'
#' @param ft_obj A `flextable` object (already cleaned of footer rows).
#' @param row_indices Integer vector of body row indices to keep.
#' @return A new `flextable` object containing only the specified rows.
#' @keywords internal
.rebuild_flextable_subset <- function(ft_obj, row_indices) {
  data    <- ft_obj$body$dataset
  sub_data <- data[row_indices, , drop = FALSE]

  # Create new flextable from subset data
  sub_ft <- flextable::flextable(sub_data)

  # Copy header structure
  sub_ft$header <- ft_obj$header

  # Copy column widths
  sub_ft$body$colwidths   <- ft_obj$body$colwidths
  sub_ft$header$colwidths <- ft_obj$header$colwidths

  sub_ft
}
