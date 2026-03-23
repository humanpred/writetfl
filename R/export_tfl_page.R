#' Lay out and render a single TFL page
#'
#' @description
#' Renders a single page with up to five vertical sections: header, caption,
#' content, footnote, and footer. Section heights are computed dynamically from
#' font metrics so that the content area occupies all remaining space. All layout
#' errors (overlapping elements, content area too short) are collected and reported
#' together before any drawing occurs.
#'
#' @param x A list with a required `content` element (a `ggplot` object or any
#'   grid grob, e.g. from `gt::as_gtable()` or `gridExtra::tableGrob()`) and
#'   optional text elements: `header_left`, `header_center`, `header_right`,
#'   `caption`, `footnote`, `footer_left`, `footer_center`, `footer_right`.
#'   List elements take precedence over the corresponding direct arguments.
#' @param padding Vertical space between adjacent present sections, as a
#'   `unit` object. Separator rules (if enabled) are drawn at the midpoint
#'   of this gap and do not consume additional space.
#' @param header_left,header_center,header_right Header text. Accepts
#'   `NULL`, a single string, or a character vector (collapsed with `"\\n"`).
#'   Horizontal justification follows the argument name (left/center/right).
#'   Vertically top-justified. Overridden by `x$header_left` etc.
#' @param caption Caption text below the header and above the content. Accepts
#'   `NULL`, a single string, or a character vector. Full-width; justification
#'   controlled by `caption_just`. Overridden by `x$caption`.
#' @param footnote Footnote text below the content. Accepts `NULL`, a single
#'   string, or a character vector. Full-width; justification controlled by
#'   `footnote_just`. Overridden by `x$footnote`.
#' @param footer_left,footer_center,footer_right Footer text. Mirror of
#'   header arguments. Vertically bottom-justified. Overridden by
#'   `x$footer_left` etc.
#' @param gp Typography specification. Accepts either a single `gpar()` object
#'   applied to all text, or a named list for section- or element-level
#'   control. Resolution priority (highest first): element-level
#'   (e.g. `gp$header_left`), section-level (e.g. `gp$header`), global
#'   `gpar()`. Example:
#'   ```r
#'   gp = list(
#'     header        = gpar(fontsize = 11, fontface = "bold"),
#'     header_right  = gpar(fontsize =  9, col = "gray50"),
#'     caption       = gpar(fontsize =  9, fontface = "italic"),
#'     footer        = gpar(fontsize =  8)
#'   )
#'   ```
#' @param header_rule Separator rule drawn between the header and the next
#'   section (caption or content), fitted within the `padding` gap. Accepts:
#'   - `FALSE`: no rule
#'   - `TRUE`: full-width rule
#'   - A numeric in `(0, 1]`: rule spanning that fraction of viewport width,
#'     centered
#'   - A grob (typically a `linesGrob`): drawn as-is, centered vertically
#'     in the padding gap.
#' @param footer_rule Separator rule between the last body section (footnote
#'   or content) and the footer. Same specification as `header_rule`.
#' @param caption_just Horizontal justification for the caption.
#' @param footnote_just Horizontal justification for the footnote.
#' @param margins Outer page margins as a `unit` vector with elements
#'   `t`, `r`, `b`, `l` (top, right, bottom, left).
#' @param min_content_height Minimum acceptable content area height as a `unit`
#'   object. An error is raised if the computed content height falls below this
#'   value.
#' @param page_i Integer page index, used to prefix layout error messages with
#'   `"Page <i>: "`. Set automatically by [writetfl::export_tfl()];
#'   not normally supplied when calling this function directly.
#' @param preview Logical. If `TRUE`, calls `grid.newpage()` and draws to the
#'   currently open device without opening or closing any device.
#' @param ... Additional arguments. Currently recognised:
#'   - `overlap_warn_mm`: numeric threshold in mm for near-miss overlap
#'     warnings. Set to `NULL` to disable.
#'
#' @return Invisibly returns `NULL`.
#'
#' @seealso [writetfl::export_tfl()] for multi-page PDF export.
#' @importFrom grid unit gpar textGrob linesGrob grobHeight grobWidth
#' @importFrom grid convertHeight convertWidth stringHeight stringWidth
#' @importFrom grid viewport pushViewport popViewport grid.newpage grid.draw
#' @importFrom grid editGrob
#' @importFrom rlang abort warn
#' @export
export_tfl_page <- function(
  x,
  padding            = grid::unit(0.5, "lines"),
  header_left        = NULL,
  header_center      = NULL,
  header_right       = NULL,
  caption            = NULL,
  footnote           = NULL,
  footer_left        = NULL,
  footer_center      = NULL,
  footer_right       = NULL,
  gp                 = grid::gpar(),
  header_rule        = FALSE,
  footer_rule        = FALSE,
  caption_just       = "left",
  footnote_just      = "left",
  margins            = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  min_content_height = grid::unit(3, "inches"),
  page_i             = NULL,
  preview            = FALSE,
  ...
) {
  dots <- list(...)
  overlap_warn_mm <- if ("overlap_warn_mm" %in% names(dots)) dots$overlap_warn_mm else 2

  # ---------------------------------------------------------------------------
  # 1. Validate x before accessing its elements
  # ---------------------------------------------------------------------------
  if (!is.list(x) || is.null(x$content)) {
    rlang::abort("`x` must be a list with a `content` element.")
  }

  # ---------------------------------------------------------------------------
  # 1b. Resolve per-page overrides from x list elements
  # ---------------------------------------------------------------------------
  resolve_from_x <- function(arg, key) {
    if (!is.null(x[[key]])) x[[key]] else arg
  }
  header_left        <- resolve_from_x(header_left,        "header_left")
  header_center      <- resolve_from_x(header_center,      "header_center")
  header_right       <- resolve_from_x(header_right,       "header_right")
  caption            <- resolve_from_x(caption,            "caption")
  footnote           <- resolve_from_x(footnote,           "footnote")
  footer_left        <- resolve_from_x(footer_left,        "footer_left")
  footer_center      <- resolve_from_x(footer_center,      "footer_center")
  footer_right       <- resolve_from_x(footer_right,       "footer_right")
  gp                 <- resolve_from_x(gp,                 "gp")
  header_rule        <- resolve_from_x(header_rule,        "header_rule")
  footer_rule        <- resolve_from_x(footer_rule,        "footer_rule")
  caption_just       <- resolve_from_x(caption_just,       "caption_just")
  footnote_just      <- resolve_from_x(footnote_just,      "footnote_just")
  padding            <- resolve_from_x(padding,            "padding")
  min_content_height <- resolve_from_x(min_content_height, "min_content_height")

  # ---------------------------------------------------------------------------
  # 1c. Validate resolved inputs
  # ---------------------------------------------------------------------------
  checkmate::assert_class(padding,            "unit", .var.name = "padding")
  checkmate::assert_class(margins,            "unit", .var.name = "margins")
  checkmate::assert_class(min_content_height, "unit", .var.name = "min_content_height")
  caption_just  <- match.arg(caption_just,  c("left", "right", "centre"))
  footnote_just <- match.arg(footnote_just, c("left", "right", "centre"))

  # ---------------------------------------------------------------------------
  # 2. Normalize all text and rule inputs
  # ---------------------------------------------------------------------------
  norm <- list(
    header_left   = normalize_text(header_left),
    header_center = normalize_text(header_center),
    header_right  = normalize_text(header_right),
    caption       = normalize_text(caption),
    footnote      = normalize_text(footnote),
    footer_left   = normalize_text(footer_left),
    footer_center = normalize_text(footer_center),
    footer_right  = normalize_text(footer_right)
  )

  header_rule_grob <- normalize_rule(header_rule)
  footer_rule_grob <- normalize_rule(footer_rule)

  # ---------------------------------------------------------------------------
  # 3. Resolve gp for all elements
  # ---------------------------------------------------------------------------
  resolved_gps <- list(
    header_left   = resolve_gp(gp, "header",   "header_left"),
    header_center = resolve_gp(gp, "header",   "header_center"),
    header_right  = resolve_gp(gp, "header",   "header_right"),
    caption       = resolve_gp(gp, "caption",  "caption"),
    footnote      = resolve_gp(gp, "footnote", "footnote"),
    footer_left   = resolve_gp(gp, "footer",   "footer_left"),
    footer_center = resolve_gp(gp, "footer",   "footer_center"),
    footer_right  = resolve_gp(gp, "footer",   "footer_right")
  )

  # ---------------------------------------------------------------------------
  # 4. Start new page and push outer_vp (inset by margins)
  # ---------------------------------------------------------------------------
  grid::grid.newpage()

  outer_vp <- .make_outer_vp(margins)
  grid::pushViewport(outer_vp)

  # ---------------------------------------------------------------------------
  # 5. Word-wrap caption and footnote to viewport width
  # ---------------------------------------------------------------------------
  vp_width_in  <- .width_in(grid::unit(1, "npc"))
  norm$caption  <- wrap_normalized_text(norm$caption,  resolved_gps$caption,
                                        vp_width_in)
  norm$footnote <- wrap_normalized_text(norm$footnote, resolved_gps$footnote,
                                        vp_width_in)

  # ---------------------------------------------------------------------------
  # 6. Build all section grobs
  # ---------------------------------------------------------------------------
  grobs <- build_section_grobs(norm, resolved_gps, caption_just, footnote_just)

  header_grobs <- list(
    header_left   = grobs$header_left,
    header_center = grobs$header_center,
    header_right  = grobs$header_right
  )
  footer_grobs <- list(
    footer_left   = grobs$footer_left,
    footer_center = grobs$footer_center,
    footer_right  = grobs$footer_right
  )

  # ---------------------------------------------------------------------------
  # 7. Determine section presence
  # ---------------------------------------------------------------------------
  header_present  <- !is.null(grobs$header_left) ||
                     !is.null(grobs$header_center) ||
                     !is.null(grobs$header_right)
  caption_present <- !is.null(grobs$caption)
  content_present <- TRUE
  footnote_present <- !is.null(grobs$footnote)
  footer_present  <- !is.null(grobs$footer_left) ||
                     !is.null(grobs$footer_center) ||
                     !is.null(grobs$footer_right)

  present <- c(header   = header_present,
               caption  = caption_present,
               content  = content_present,
               footnote = footnote_present,
               footer   = footer_present)

  # ---------------------------------------------------------------------------
  # 8. Measurement phase (outer_vp active; vp_width_in already computed)
  # ---------------------------------------------------------------------------
  vp_height_in <- .height_in(grid::unit(1, "npc"))
  padding_in   <- .height_in(padding)

  section_heights <- measure_section_heights(
    header_grobs, grobs$caption, grobs$footnote, footer_grobs, norm
  )

  header_widths <- measure_header_widths(header_grobs)
  footer_widths <- measure_footer_widths(footer_grobs)

  # ---------------------------------------------------------------------------
  # 9. Validation phase — collect all errors before drawing
  # ---------------------------------------------------------------------------
  errors <- character(0)

  errors <- c(errors,
    check_overlap(header_widths, vp_width_in, overlap_warn_mm, row_name = "header"))
  errors <- c(errors,
    check_overlap(footer_widths, vp_width_in, overlap_warn_mm, row_name = "footer"))

  content_h_in <- compute_content_height(vp_height_in, section_heights, present, padding_in)
  errors       <- check_content_height(content_h_in, min_content_height, errors)

  if (length(errors) > 0) {
    grid::popViewport()
    page_prefix <- if (!is.null(page_i)) paste0("Page ", page_i, ": ") else ""
    rlang::abort(paste(paste0(page_prefix, errors), collapse = "\n"))
  }

  # ---------------------------------------------------------------------------
  # 10. Drawing phase — Y-cursor accounting (inches from bottom of outer_vp)
  # ---------------------------------------------------------------------------
  # y_cursor tracks position from the BOTTOM of outer_vp (like grid npc).
  # Starts at vp_height_in (top). npc_y = y_cursor / vp_height_in.
  y_cursor <- vp_height_in

  # --- Header ---
  if (header_present) {
    draw_header_section(header_grobs, y_top_npc = y_cursor / vp_height_in)
    y_cursor <- y_cursor - section_heights$header
  }

  # --- Header rule + padding (between header and caption/content) ---
  if (header_present && (caption_present || content_present)) {
    y_mid_npc <- (y_cursor - padding_in / 2) / vp_height_in
    draw_rule(header_rule_grob, y_mid_npc)
    y_cursor <- y_cursor - padding_in
  }

  # --- Caption ---
  if (caption_present) {
    draw_caption_section(grobs$caption, y_top_npc = y_cursor / vp_height_in)
    y_cursor <- y_cursor - section_heights$caption
  }

  # --- Caption-content padding ---
  if (caption_present && content_present) {
    y_cursor <- y_cursor - padding_in
  }

  # --- Content viewport ---
  content_vp <- grid::viewport(
    x      = grid::unit(0, "npc"),
    y      = grid::unit(y_cursor - content_h_in, "inches"),
    width  = grid::unit(1, "npc"),
    height = grid::unit(content_h_in, "inches"),
    just   = c("left", "bottom"),
    name   = "content_vp"
  )
  draw_content(x$content, content_vp)
  y_cursor <- y_cursor - content_h_in

  # --- Content-footnote padding ---
  if (content_present && footnote_present) {
    y_cursor <- y_cursor - padding_in
  }

  # --- Footnote ---
  if (footnote_present) {
    y_bottom_npc <- (y_cursor - section_heights$footnote) / vp_height_in
    draw_footnote_section(grobs$footnote, y_bottom_npc)
    y_cursor <- y_cursor - section_heights$footnote
  }

  # --- Footer rule + padding (between footnote/content and footer) ---
  if (footer_present && (footnote_present || content_present)) {
    y_mid_npc <- (y_cursor - padding_in / 2) / vp_height_in
    draw_rule(footer_rule_grob, y_mid_npc)
    y_cursor <- y_cursor - padding_in
  }

  # --- Footer ---
  if (footer_present) {
    y_bottom_npc <- (y_cursor - section_heights$footer) / vp_height_in
    draw_footer_section(footer_grobs, y_bottom_npc)
  }

  grid::popViewport()
  invisible(NULL)
}
