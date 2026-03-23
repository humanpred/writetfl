# gt.R — S3 method and conversion for gt_tbl objects
#
# Functions:
#   export_tfl.gt_tbl()        — S3 method dispatched by export_tfl()
#   gt_to_pagelist()           — convert a gt_tbl to a list of page specs
#   .extract_gt_annotations()  — extract title/subtitle/footnotes/source notes
#   .clean_gt()                — remove annotations from gt object before rendering
#   .gt_content_height()       — compute available content height for gt pagination
#   .gt_grob_height()          — measure a gt grob height in a scratch device
#   .gt_row_groups()           — extract row group boundaries from a gt object
#   .rebuild_gt_subset()       — create a sub-gt from a row index subset
#   .paginate_gt()             — greedily assign row groups to pages

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
  pages <- gt_to_pagelist(x, pg_width, pg_height, dots, page_num)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a gt_tbl object to a list of page specification lists
#'
#' Extracts title, subtitle, source notes, and footnotes from the gt object
#' into writetfl annotation fields (caption, footnote), removes them from
#' the gt object to avoid duplication, and converts the table body to a
#' grid grob via [gt::as_gtable()].
#'
#' When the rendered table exceeds the available content height, rows are
#' split across multiple pages respecting row group boundaries.
#'
#' @param gt_obj A `gt_tbl` object.
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional arguments from `...`.
#' @param page_num Glue template for page numbering (used for height calc).
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
gt_to_pagelist <- function(gt_obj, pg_width = 11, pg_height = 8.5,
                           dots = list(), page_num = "Page {i} of {n}") {
  annot   <- .extract_gt_annotations(gt_obj)
  cleaned <- .clean_gt(gt_obj)
  grob    <- gt::as_gtable(cleaned)

  # Measure available content height
  content_h <- .gt_content_height(pg_width, pg_height, dots, page_num, annot)
  grob_h    <- .gt_grob_height(grob, pg_width, pg_height)

  # If the table fits on a single page, return immediately
  if (grob_h <= content_h) {
    page_spec <- list(content = grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    return(list(page_spec))
  }

  # Paginate: split rows across pages
  row_chunks <- .paginate_gt(cleaned, content_h, pg_width, pg_height)

  lapply(row_chunks, function(row_idx) {
    sub_gt   <- .rebuild_gt_subset(cleaned, row_idx)
    sub_grob <- gt::as_gtable(sub_gt)
    page_spec <- list(content = sub_grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    page_spec
  })
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

#' Compute available content height for gt table pagination
#'
#' Reuses [compute_table_content_area()] to measure how much vertical space
#' the content gets after header, caption, footnote, and footer sections are
#' accounted for.
#'
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional page-layout arguments.
#' @param page_num Glue template for page numbering.
#' @param annot Annotation list from [.extract_gt_annotations()].
#' @return Numeric scalar: available content height in inches.
#' @keywords internal
.gt_content_height <- function(pg_width, pg_height, dots, page_num, annot) {
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

#' Measure a gt grob's height in a scratch device
#'
#' @param grob A gtable grob from [gt::as_gtable()].
#' @param pg_width,pg_height Page dimensions for the scratch device.
#' @return Numeric scalar: grob height in inches.
#' @keywords internal
.gt_grob_height <- function(grob, pg_width, pg_height) {
  scratch <- tempfile(fileext = ".pdf")
  grDevices::pdf(scratch, width = pg_width, height = pg_height)
  on.exit({
    grDevices::dev.off()
    unlink(scratch)
  })
  grid::convertHeight(grid::grobHeight(grob), "inches", valueOnly = TRUE)
}

#' Extract row group boundaries from a gt object
#'
#' Returns a list of integer vectors, each containing row indices for one
#' group. If no row groups are defined, each row is its own "group".
#'
#' @param gt_obj A `gt_tbl` object (already cleaned).
#' @return A list of integer vectors.
#' @keywords internal
.gt_row_groups <- function(gt_obj) {
  stub_df    <- gt_obj[["_stub_df"]]
  row_groups <- gt_obj[["_row_groups"]]
  n_rows     <- nrow(gt_obj[["_data"]])

  has_groups <- length(row_groups) > 0L &&
    any(!is.na(stub_df$group_id))

  if (has_groups) {
    # Respect the display order from _row_groups
    groups <- row_groups
    lapply(groups, function(g) which(stub_df$group_id == g))
  } else {
    # No groups: each row is its own "group"
    as.list(seq_len(n_rows))
  }
}

#' Greedily assign row groups to pages
#'
#' Measures the gtable height of cumulative row subsets and splits when a
#' page would overflow.
#'
#' @param cleaned_gt A cleaned `gt_tbl` (no annotations).
#' @param content_h Available content height in inches.
#' @param pg_width,pg_height Page dimensions for scratch device.
#' @return A list of integer vectors (row indices per page).
#' @keywords internal
.paginate_gt <- function(cleaned_gt, content_h, pg_width, pg_height) {
  groups <- .gt_row_groups(cleaned_gt)

  pages        <- list()
  current_rows <- integer(0L)

  for (grp_idx in seq_along(groups)) {
    candidate_rows <- c(current_rows, groups[[grp_idx]])
    sub_gt    <- .rebuild_gt_subset(cleaned_gt, candidate_rows)
    sub_grob  <- gt::as_gtable(sub_gt)
    h         <- .gt_grob_height(sub_grob, pg_width, pg_height)

    if (h > content_h && length(current_rows) > 0L) {
      # Current group doesn't fit — finalize current page
      pages <- c(pages, list(current_rows))
      current_rows <- groups[[grp_idx]]
    } else {
      current_rows <- candidate_rows
    }
  }
  if (length(current_rows) > 0L) {
    pages <- c(pages, list(current_rows))
  }

  pages
}

#' Rebuild a gt object from a row index subset
#'
#' Creates a new `gt_tbl` from the subset of rows, preserving column
#' labels, row groups, options, spanners, formatting, and styles.
#'
#' @param gt_obj A `gt_tbl` object (already cleaned of annotations).
#' @param row_indices Integer vector of row indices to keep.
#' @return A new `gt_tbl` object containing only the specified rows.
#' @keywords internal
.rebuild_gt_subset <- function(gt_obj, row_indices) {

  data     <- gt_obj[["_data"]]
  stub_df  <- gt_obj[["_stub_df"]]
  sub_data <- data[row_indices, , drop = FALSE]

  # Build row-index mapping: old index → new index
  idx_map <- stats::setNames(seq_along(row_indices), row_indices)

  # Determine row groups for the subset
  sub_stub    <- stub_df[row_indices, , drop = FALSE]
  has_groups  <- any(!is.na(sub_stub$group_id))

  if (has_groups) {
    # Preserve group structure: use .by grouping
    group_col <- ".writetfl_grp_"
    sub_data[[group_col]] <- sub_stub$group_id
    sub_gt <- gt::gt(sub_data, groupname_col = group_col)
    # Set display order from original _row_groups, filtered to present groups
    present_groups <- unique(sub_stub$group_id[!is.na(sub_stub$group_id)])
    orig_order <- gt_obj[["_row_groups"]]
    ordered_groups <- orig_order[orig_order %in% present_groups]
    sub_gt[["_row_groups"]] <- ordered_groups
  } else {
    sub_gt <- gt::gt(sub_data)
  }

  # Copy column metadata (labels, alignment, etc.)
  sub_gt[["_boxhead"]] <- gt_obj[["_boxhead"]]

  # Copy table options
  sub_gt[["_options"]] <- gt_obj[["_options"]]

  # Copy spanners
  sub_gt[["_spanners"]] <- gt_obj[["_spanners"]]

  # Copy stubhead
  sub_gt[["_stubhead"]] <- gt_obj[["_stubhead"]]

  # Re-index formats
  orig_formats <- gt_obj[["_formats"]]
  if (length(orig_formats) > 0L) {
    sub_gt[["_formats"]] <- lapply(orig_formats, function(fmt) {
      old_rows <- fmt$rows
      keep     <- old_rows %in% row_indices
      if (!any(keep)) return(NULL)
      fmt$rows <- as.integer(idx_map[as.character(old_rows[keep])])
      fmt
    })
    sub_gt[["_formats"]] <- Filter(Negate(is.null), sub_gt[["_formats"]])
  }

  # Re-index styles
  orig_styles <- gt_obj[["_styles"]]
  if (!is.null(orig_styles) && nrow(orig_styles) > 0L) {
    # Only keep data-location styles that reference our rows
    data_mask <- orig_styles$locname == "data" &
      !is.na(orig_styles$rownum) &
      orig_styles$rownum %in% row_indices
    non_data_mask <- orig_styles$locname != "data"
    keep_mask <- data_mask | non_data_mask
    sub_styles <- orig_styles[keep_mask, , drop = FALSE]
    # Re-index row numbers for data styles
    if (nrow(sub_styles) > 0L) {
      is_data <- sub_styles$locname == "data" & !is.na(sub_styles$rownum)
      sub_styles$rownum[is_data] <- as.integer(
        idx_map[as.character(sub_styles$rownum[is_data])]
      )
    }
    sub_gt[["_styles"]] <- sub_styles
  }

  # Re-index transforms (have $resolved$rows)
  orig_transforms <- gt_obj[["_transforms"]]
  if (length(orig_transforms) > 0L) {
    sub_gt[["_transforms"]] <- lapply(orig_transforms, function(tr) {
      old_rows <- tr$resolved$rows
      keep     <- old_rows %in% row_indices
      if (!any(keep)) return(NULL)
      tr$resolved$rows <- as.integer(idx_map[as.character(old_rows[keep])])
      tr
    })
    sub_gt[["_transforms"]] <- Filter(Negate(is.null),
                                      sub_gt[["_transforms"]])
  }

  sub_gt[["_locale"]] <- gt_obj[["_locale"]]

  # Re-index substitutions (have $rows like formats)
  orig_subs <- gt_obj[["_substitutions"]]
  if (length(orig_subs) > 0L) {
    sub_gt[["_substitutions"]] <- lapply(orig_subs, function(s) {
      old_rows <- s$rows
      keep     <- old_rows %in% row_indices
      if (!any(keep)) return(NULL)  # nocov
      s$rows <- as.integer(idx_map[as.character(old_rows[keep])])
      s
    })
    sub_gt[["_substitutions"]] <- Filter(Negate(is.null),
                                         sub_gt[["_substitutions"]])
  }

  # Copy summary definitions, filtering to groups present in subset
  orig_summary <- gt_obj[["_summary"]]
  if (length(orig_summary) > 0L && has_groups) {
    sub_gt[["_summary"]] <- lapply(orig_summary, function(s) {
      if (!is.null(s$groups) && is.character(s$groups)) {
        s$groups <- intersect(s$groups, present_groups)
        if (length(s$groups) == 0L) return(NULL)
      }
      s
    })
    sub_gt[["_summary"]] <- Filter(Negate(is.null), sub_gt[["_summary"]])
  } else if (length(orig_summary) > 0L) {
    # Grand summary (no group filter needed)
    sub_gt[["_summary"]] <- orig_summary
  }

  # Copy summary column config (if any; empty in gt <= 1.2.0)
  if (length(gt_obj[["_summary_cols"]]) > 0L) {
    sub_gt[["_summary_cols"]] <- gt_obj[["_summary_cols"]]  # nocov
  }

  sub_gt
}
