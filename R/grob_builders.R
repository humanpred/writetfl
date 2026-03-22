# grob_builders.R — Build all section grobs from normalized inputs

#' Build a text grob from a normalized text input
#'
#' @param norm Output of normalize_text().
#' @param resolved_gp Output of resolve_gp() for this element.
#' @param x_npc Horizontal position in npc (0, 0.5, or 1).
#' @param just Justification vector passed to textGrob (e.g. c("left", "top")).
#' @return A textGrob or NULL if norm$text is NULL.
#' @keywords internal
build_text_grob <- function(norm, resolved_gp, x_npc, just) {
  if (is.null(norm$text)) return(NULL)
  grid::textGrob(
    label = norm$text,
    x     = grid::unit(x_npc, "npc"),
    y     = grid::unit(0.5, "npc"),  # y will be set at draw time via editGrob
    just  = just,
    gp    = resolved_gp
  )
}

#' Build all section grobs for a page
#'
#' @param norm_inputs Named list of normalize_text() outputs for all 8 elements:
#'   header_left, header_center, header_right, caption, footnote,
#'   footer_left, footer_center, footer_right.
#' @param resolved_gps Named list of resolve_gp() outputs for all 8 elements.
#' @param caption_just,footnote_just Justification strings.
#' @return Named list of grobs (NULL where element is absent).
#' @keywords internal
build_section_grobs <- function(norm_inputs, resolved_gps,
                                caption_just, footnote_just) {
  list(
    header_left   = build_text_grob(norm_inputs$header_left,
                                    resolved_gps$header_left,
                                    x_npc = 0,
                                    just  = c("left",   "top")),
    header_center = build_text_grob(norm_inputs$header_center,
                                    resolved_gps$header_center,
                                    x_npc = 0.5,
                                    just  = c("center", "top")),
    header_right  = build_text_grob(norm_inputs$header_right,
                                    resolved_gps$header_right,
                                    x_npc = 1,
                                    just  = c("right",  "top")),
    caption       = build_text_grob(norm_inputs$caption,
                                    resolved_gps$caption,
                                    x_npc = 0,
                                    just  = c(caption_just, "top")),
    footnote      = build_text_grob(norm_inputs$footnote,
                                    resolved_gps$footnote,
                                    x_npc = 0,
                                    just  = c(footnote_just, "bottom")),
    footer_left   = build_text_grob(norm_inputs$footer_left,
                                    resolved_gps$footer_left,
                                    x_npc = 0,
                                    just  = c("left",   "bottom")),
    footer_center = build_text_grob(norm_inputs$footer_center,
                                    resolved_gps$footer_center,
                                    x_npc = 0.5,
                                    just  = c("center", "bottom")),
    footer_right  = build_text_grob(norm_inputs$footer_right,
                                    resolved_gps$footer_right,
                                    x_npc = 1,
                                    just  = c("right",  "bottom"))
  )
}
