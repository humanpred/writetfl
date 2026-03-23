# table1.R — S3 method and conversion for table1 objects
#
# Functions:
#   export_tfl.table1()              — S3 method dispatched by export_tfl()
#   table1_to_pagelist()             — convert a table1 to a list of page specs
#   .extract_table1_annotations()    — extract caption and footnote
#   .table1_variable_groups()        — identify variable-group row boundaries
#   .paginate_table1()               — group-aware greedy pagination

#' @export
export_tfl.table1 <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  rlang::check_installed("table1", reason = "to export table1 tables")
  rlang::check_installed("flextable", reason = "to export table1 tables")
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  pages <- table1_to_pagelist(x, pg_width, pg_height, dots, page_num)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a table1 object to a list of page specification lists
#'
#' Extracts caption and footnote from the table1 object's internal structure,
#' converts to a flextable via [table1::t1flex()], then renders via
#' [flextable::gen_grob()]. When the rendered table exceeds the available
#' content height, rows are split across multiple pages using group-aware
#' pagination that keeps each variable's label and summary statistics together.
#'
#' @param t1_obj A `table1` object.
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional arguments from `...`.
#' @param page_num Glue template for page numbering (used for height calc).
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
table1_to_pagelist <- function(t1_obj, pg_width = 11, pg_height = 8.5,
                                dots = list(), page_num = "Page {i} of {n}") {
  annot  <- .extract_table1_annotations(t1_obj)
  groups <- .table1_variable_groups(t1_obj)

  # Convert to flextable — t1flex() preserves bold labels, indentation, etc.
  ft <- table1::t1flex(t1_obj)

  # Clean: remove footer rows (we already extracted footnote)
  ft <- .clean_flextable(ft)
  # Clear caption (we already extracted it)
  ft$caption <- list(value = NULL)

  # Measure available content area
  content_h <- .flextable_content_height(pg_width, pg_height, dots, page_num,
                                         annot)
  content_w <- .flextable_content_width(pg_width, dots)

  # Convert to grob and measure height
  grob   <- .flextable_to_grob(ft, content_w)
  grob_h <- .flextable_grob_height(grob)

  # If the table fits on a single page, return immediately
  if (grob_h <= content_h) {
    page_spec <- list(content = grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    return(list(page_spec))
  }

  # Paginate: group-aware splitting
  ft_pages <- .paginate_table1(ft, groups, content_h, content_w)

  lapply(ft_pages, function(ft_page) {
    page_grob <- .flextable_to_grob(ft_page, content_w)
    page_spec <- list(content = page_grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    page_spec
  })
}

#' Extract annotations from a table1 object
#'
#' Extracts caption and footnote from the internal `"obj"` attribute of a
#' table1 object.
#'
#' @param t1_obj A `table1` object.
#' @return A list with `$caption` (character or NULL) and `$footnote`
#'   (character or NULL).
#' @keywords internal
.extract_table1_annotations <- function(t1_obj) {
  obj <- attr(t1_obj, "obj", exact = TRUE)

  caption <- obj$caption
  if (!is.null(caption) && (!nzchar(caption) || all(is.na(caption)))) {
    caption <- NULL
  }

  footnote <- obj$footnote
  if (!is.null(footnote)) {
    footnote <- footnote[nzchar(footnote) & !is.na(footnote)]
    if (length(footnote) == 0L) {
      footnote <- NULL
    } else {
      footnote <- paste(footnote, collapse = "\n")
    }
  }

  list(caption = caption, footnote = footnote)
}

#' Identify variable-group row boundaries in a table1 object
#'
#' Each variable in a table1 output forms a "group" consisting of a bold
#' variable-label row followed by indented summary-statistic rows. This
#' function returns the flextable body row indices for each group, derived
#' from the `contents` matrices in the table1 object's internal structure.
#'
#' @param t1_obj A `table1` object.
#' @return A list of integer vectors, each containing the body row indices
#'   for one variable group (label row + summary rows).
#' @keywords internal
.table1_variable_groups <- function(t1_obj) {
  obj <- attr(t1_obj, "obj", exact = TRUE)
  contents <- obj$contents

  groups <- list()
  cumrow <- 0L
  for (i in seq_along(contents)) {
    nr <- nrow(contents[[i]])
    rows <- seq(cumrow + 1L, cumrow + nr)
    groups <- c(groups, list(rows))
    cumrow <- cumrow + nr
  }
  groups
}

#' Group-aware greedy pagination for table1 flextables
#'
#' Splits a table1-derived flextable across pages, keeping each variable's
#' label and summary statistic rows together. If a single variable group
#' exceeds the page height, falls back to row-by-row splitting within that
#' group.
#'
#' @param ft_obj A cleaned `flextable` (converted from table1, no footer rows).
#' @param groups List of integer vectors from [.table1_variable_groups()].
#' @param content_h Available content height in inches.
#' @param content_w Available content width in inches.
#' @return A list of `flextable` objects (one per page).
#' @keywords internal
.paginate_table1 <- function(ft_obj, groups, content_h, content_w) {
  pages        <- list()
  current_rows <- integer(0L)

  for (grp_idx in seq_along(groups)) {
    candidate_rows <- c(current_rows, groups[[grp_idx]])
    sub_ft   <- .rebuild_flextable_subset(ft_obj, candidate_rows)
    sub_grob <- .flextable_to_grob(sub_ft, content_w)
    h        <- .flextable_grob_height(sub_grob)

    if (h > content_h && length(current_rows) > 0L) {
      # Current group doesn't fit — finalize current page
      pages <- c(pages, list(.rebuild_flextable_subset(ft_obj, current_rows)))
      # Try the group alone
      grp_ft   <- .rebuild_flextable_subset(ft_obj, groups[[grp_idx]])
      grp_grob <- .flextable_to_grob(grp_ft, content_w)
      grp_h    <- .flextable_grob_height(grp_grob)

      if (grp_h > content_h) {
        # Oversized group: fall back to row-by-row within this group
        row_pages <- .paginate_oversized_group(ft_obj, groups[[grp_idx]],
                                               content_h, content_w)
        # All but the last sub-page are complete pages
        for (rp_idx in seq_along(row_pages)) {
          if (rp_idx < length(row_pages)) {
            pages <- c(pages, list(row_pages[[rp_idx]]))
          } else {
            # Last sub-page becomes the start of the next accumulation
            current_rows <- row_pages[[rp_idx]]$body_rows
          }
        }
      } else {
        current_rows <- groups[[grp_idx]]
      }
    } else if (h > content_h && length(current_rows) == 0L) {
      # First group on an empty page and it still doesn't fit
      row_pages <- .paginate_oversized_group(ft_obj, groups[[grp_idx]],
                                             content_h, content_w)
      for (rp_idx in seq_along(row_pages)) {
        if (rp_idx < length(row_pages)) {
          pages <- c(pages, list(row_pages[[rp_idx]]))
        } else {
          current_rows <- row_pages[[rp_idx]]$body_rows
        }
      }
    } else {
      current_rows <- candidate_rows
    }
  }

  if (length(current_rows) > 0L) {
    pages <- c(pages, list(.rebuild_flextable_subset(ft_obj, current_rows)))
  }

  pages
}

#' Paginate an oversized variable group row-by-row
#'
#' When a single variable group (label + summary rows) exceeds the available
#' content height, falls back to row-by-row greedy splitting.
#'
#' @param ft_obj The full flextable object.
#' @param grp_rows Integer vector of body row indices for the oversized group.
#' @param content_h Available content height in inches.
#' @param content_w Available content width in inches.
#' @return A list of objects. Complete sub-pages are `flextable` objects.
#'   The last element is a list with `$body_rows` (integer vector of remaining
#'   row indices) for further accumulation.
#' @keywords internal
.paginate_oversized_group <- function(ft_obj, grp_rows, content_h, content_w) {
  results      <- list()
  current_rows <- integer(0L)

  for (row_idx in grp_rows) {
    candidate <- c(current_rows, row_idx)
    sub_ft   <- .rebuild_flextable_subset(ft_obj, candidate)
    sub_grob <- .flextable_to_grob(sub_ft, content_w)
    h        <- .flextable_grob_height(sub_grob)

    if (h > content_h && length(current_rows) > 0L) {
      results <- c(results, list(.rebuild_flextable_subset(ft_obj,
                                                           current_rows)))
      current_rows <- row_idx
    } else {
      current_rows <- candidate
    }
  }

  # Last batch: return as a list with body_rows for further accumulation
  if (length(current_rows) > 0L) {
    results <- c(results, list(list(body_rows = current_rows)))
  }

  results
}
