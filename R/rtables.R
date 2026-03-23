# rtables.R — S3 method and conversion for rtables VTableTree objects
#
# Functions:
#   export_tfl.VTableTree()        — S3 method dispatched by export_tfl()
#   rtables_to_pagelist()          — convert a VTableTree to a list of page specs
#   .extract_rtables_annotations() — extract title/subtitles/footers
#   .clean_rtables()               — strip annotations from rtables object
#   .rtables_content_height()      — compute available content height
#   .rtables_lpp_cpp()             — convert inches to lines/chars per page
#   .rtables_to_grob()             — render a single page to textGrob

#' @export
export_tfl.VTableTree <- function(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
) {
  rlang::check_installed("rtables", reason = "to export rtables tables")
  dots <- list(...)
  .validate_export_args(page_num, preview, file)
  pages <- rtables_to_pagelist(x, pg_width, pg_height, dots, page_num)
  .export_tfl_pages(pages, file, pg_width, pg_height, page_num, preview, dots)
}

#' Convert a VTableTree object to a list of page specification lists
#'
#' Extracts main title + subtitles as caption and main footer + provenance
#' footer as footnote, strips them from the rtables object to avoid
#' duplication, then renders via `toString()` into a `textGrob`.
#'
#' When the table exceeds the available content height, rtables' built-in
#' `paginate_table()` splits it across pages respecting row group boundaries.
#'
#' @param rt_obj A `VTableTree` object.
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional arguments from `...`.
#' @param page_num Glue template for page numbering (used for height calc).
#' @return A list of page spec lists, each with at least `$content`.
#' @keywords internal
rtables_to_pagelist <- function(rt_obj, pg_width = 11, pg_height = 8.5,
                                dots = list(), page_num = "Page {i} of {n}") {
  annot   <- .extract_rtables_annotations(rt_obj)
  cleaned <- .clean_rtables(rt_obj)

  # Font parameters from dots or defaults
  font_family <- dots$rtables_font_family %||% "Courier"
  font_size   <- dots$rtables_font_size   %||% 8
  lineheight  <- dots$rtables_lineheight   %||% 1

  # Measure available content area
  content_h <- .rtables_content_height(pg_width, pg_height, dots, page_num,
                                       annot)
  content_w <- .rtables_content_width(pg_width, dots)

  # Compute lines-per-page and chars-per-page
  lpp_cpp <- .rtables_lpp_cpp(content_h, content_w, font_family, font_size,
                              lineheight)

  # Paginate using rtables' built-in pagination
  pages <- rtables::paginate_table(
    cleaned,
    lpp = lpp_cpp$lpp,
    cpp = lpp_cpp$cpp,
    font_family = font_family,
    font_size   = font_size,
    lineheight  = lineheight,
    verbose     = FALSE
  )

  # Convert each page to a grob and assemble page specs
  lapply(pages, function(page) {
    grob <- .rtables_to_grob(page, font_family, font_size, lineheight)
    page_spec <- list(content = grob)
    if (!is.null(annot$caption))  page_spec$caption  <- annot$caption
    if (!is.null(annot$footnote)) page_spec$footnote <- annot$footnote
    page_spec
  })
}

#' Extract annotations from a VTableTree object
#'
#' Extracts main title + subtitles as caption and main footer + provenance
#' footer as footnote text.
#'
#' @param rt_obj A `VTableTree` object.
#' @return A list with `$caption` (character or NULL) and `$footnote`
#'   (character or NULL).
#' @keywords internal
.extract_rtables_annotations <- function(rt_obj) {
  # Caption: main_title + subtitles
  mt <- formatters::main_title(rt_obj)
  st <- formatters::subtitles(rt_obj)

  caption_parts <- c(
    if (length(mt) > 0L && nzchar(mt)) mt,
    st[nzchar(st)]
  )
  caption <- if (length(caption_parts) > 0L) {
    paste(caption_parts, collapse = "\n")
  }

  # Footnote: main_footer + prov_footer
  mf <- formatters::main_footer(rt_obj)
  pf <- formatters::prov_footer(rt_obj)

  fn_parts <- c(mf[nzchar(mf)], pf[nzchar(pf)])
  footnote <- if (length(fn_parts) > 0L) {
    paste(fn_parts, collapse = "\n")
  }

  list(caption = caption, footnote = footnote)
}

#' Remove annotations from a VTableTree object
#'
#' Strips main title, subtitles, main footer, and provenance footer so that
#' `toString()` renders only the table body.
#'
#' @param rt_obj A `VTableTree` object.
#' @return A cleaned `VTableTree` object.
#' @keywords internal
.clean_rtables <- function(rt_obj) {
  formatters::main_title(rt_obj)  <- ""
  formatters::subtitles(rt_obj)   <- character(0L)
  formatters::main_footer(rt_obj) <- character(0L)
  formatters::prov_footer(rt_obj) <- character(0L)
  rt_obj
}

#' Compute available content height for rtables pagination
#'
#' Reuses [compute_table_content_area()] to measure how much vertical space
#' the content gets after header, caption, footnote, and footer sections are
#' accounted for.
#'
#' @param pg_width,pg_height Page dimensions in inches.
#' @param dots Named list of additional page-layout arguments.
#' @param page_num Glue template for page numbering.
#' @param annot Annotation list from [.extract_rtables_annotations()].
#' @return Numeric scalar: available content height in inches.
#' @keywords internal
.rtables_content_height <- function(pg_width, pg_height, dots, page_num,
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
.rtables_content_width <- function(pg_width, dots) {
  margins <- if (!is.null(dots$margins)) {
    dots$margins
  } else {
    .tfl_page_defaults$margins
  }
  margin_vals <- grid::convertWidth(margins, "inches", valueOnly = TRUE)
  # margins are c(top, right, bottom, left)
  pg_width - margin_vals[2] - margin_vals[4]
}

#' Convert content dimensions to lines-per-page and chars-per-page
#'
#' @param content_h Available content height in inches.
#' @param content_w Available content width in inches.
#' @param font_family Font family name.
#' @param font_size Font size in points.
#' @param lineheight Line height multiplier.
#' @return A list with `$lpp` and `$cpp` (positive integers).
#' @keywords internal
.rtables_lpp_cpp <- function(content_h, content_w, font_family = "Courier",
                             font_size = 8, lineheight = 1) {
  # Line height in inches
  line_h_in <- (font_size / 72) * lineheight
  lpp <- floor(content_h / line_h_in)

  # Character width: measure "M" in the target font using a scratch device
  scratch <- tempfile(fileext = ".pdf")
  grDevices::pdf(scratch, width = 10, height = 10)
  on.exit({
    grDevices::dev.off()
    unlink(scratch)
  })
  grid::pushViewport(grid::viewport(
    gp = grid::gpar(fontfamily = font_family, fontsize = font_size)
  ))
  char_w_in <- grid::convertWidth(grid::stringWidth("M"), "inches",
                                  valueOnly = TRUE)
  grid::popViewport()

  cpp <- floor(content_w / char_w_in)

  list(lpp = max(as.integer(lpp), 1L), cpp = max(as.integer(cpp), 1L))
}

#' Convert a single rtables page to a textGrob
#'
#' @param rt_page A `VTableTree` object (one paginated page).
#' @param font_family Font family name.
#' @param font_size Font size in points.
#' @param lineheight Line height multiplier.
#' @return A grid `textGrob`.
#' @keywords internal
.rtables_to_grob <- function(rt_page, font_family = "Courier",
                             font_size = 8, lineheight = 1) {
  txt <- formatters::toString(rt_page)
  grid::textGrob(
    txt,
    x    = grid::unit(0, "npc"),
    y    = grid::unit(1, "npc"),
    just = c("left", "top"),
    gp   = grid::gpar(fontfamily = font_family, fontsize = font_size,
                      lineheight = lineheight)
  )
}
