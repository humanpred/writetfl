# gt.R — S3 method and conversion for gt_tbl objects
#
# Functions:
#   export_tfl.gt_tbl()        — S3 method dispatched by export_tfl()
#   gt_to_pagelist()           — convert a gt_tbl to a list of page specs
#   .extract_gt_annotations()  — extract title/subtitle/footnotes/source notes
#   .clean_gt()                — remove annotations from gt object before rendering

#' @export
export_tfl.gt_tbl <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  rlang::check_installed("gt", reason = "to export gt tables")
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  pages <- gt_to_pagelist(x)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a gt_tbl object to a list of page specification lists
#'
#' Extracts title, subtitle, source notes, and footnotes from the gt object
#' into writetfl annotation fields (caption, footnote), removes them from
#' the gt object to avoid duplication, and converts the table body to a
#' grid grob via [gt::as_gtable()].
#'
#' @param gt_obj A `gt_tbl` object.
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
gt_to_pagelist <- function(gt_obj) {
  annot   <- .extract_gt_annotations(gt_obj)
  cleaned <- .clean_gt(gt_obj)
  grob    <- gt::as_gtable(cleaned)

  page_spec <- list(content = grob)
  if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
  if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote

  list(page_spec)
}

#' Extract annotations from a gt_tbl object
#'
#' Extracts title + subtitle as caption and source notes + footnotes as
#' footnote text.
#'
#' @param gt_obj A `gt_tbl` object.
#' @return A list with `$caption` (character or NULL) and `$footnote`
#'   (character or NULL).
#' @keywords internal
.extract_gt_annotations <- function(gt_obj) {
  heading <- gt_obj[["_heading"]]

  # Title and subtitle → caption
  title <- if (!is.null(heading$title) && !is.na(heading$title) &&
               nzchar(heading$title)) heading$title
  subtitle <- if (!is.null(heading$subtitle) && !is.na(heading$subtitle) &&
                  nzchar(heading$subtitle)) heading$subtitle

  caption <- if (!is.null(title) && !is.null(subtitle)) {
    paste(title, subtitle, sep = "\n")
  } else {
    title %||% subtitle
  }

  # Source notes → footnote
  src_notes <- gt_obj[["_source_notes"]]
  src_text <- if (length(src_notes) > 0L) {
    paste(vapply(src_notes, as.character, character(1L)), collapse = "\n")
  }

  # Cell-level footnotes → append to footnote
  fn_df <- gt_obj[["_footnotes"]]
  fn_text <- if (!is.null(fn_df) && nrow(fn_df) > 0L) {
    fn_strings <- vapply(fn_df$footnotes, as.character, character(1L))
    paste(unique(fn_strings), collapse = "\n")
  }

  # Combine footnotes and source notes
  parts <- c(fn_text, src_text)
  parts <- parts[nzchar(parts)]
  footnote <- if (length(parts) > 0L) paste(parts, collapse = "\n")

  list(caption = caption, footnote = footnote)
}

#' Remove annotations from a gt_tbl object
#'
#' Strips title, subtitle, source notes, and footnotes so that
#' [gt::as_gtable()] renders only the table body.
#'
#' @param gt_obj A `gt_tbl` object.
#' @return A cleaned `gt_tbl` object.
#' @keywords internal
.clean_gt <- function(gt_obj) {
  gt_obj |> gt::rm_header() |> gt::rm_source_notes() |> gt::rm_footnotes()
}
