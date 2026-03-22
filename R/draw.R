# draw.R — Drawing helpers
# All functions assume the correct viewport is active when called.
# See ARCHITECTURE.md "Y-coordinate accounting" for draw order.

#' Draw header section (left, center, right grobs) at a given top edge
#'
#' @param grobs Named list from build_section_grobs(): header_left,
#'   header_center, header_right.
#' @param y_top_npc Top edge of the header row in npc units (outer_vp).
#' @keywords internal
draw_header_section <- function(grobs, y_top_npc) {
  for (nm in c("header_left", "header_center", "header_right")) {
    g <- grobs[[nm]]
    if (!is.null(g)) {
      grid::grid.draw(grid::editGrob(g, y = grid::unit(y_top_npc, "npc")))
    }
  }
}

#' Draw caption section (single full-width grob) at a given top edge
#'
#' @param grob The caption textGrob, or NULL.
#' @param y_top_npc Top edge of the caption in npc units (outer_vp).
#' @keywords internal
draw_caption_section <- function(grob, y_top_npc) {
  if (!is.null(grob)) {
    grid::grid.draw(grid::editGrob(grob, y = grid::unit(y_top_npc, "npc")))
  }
}

#' Draw footnote section at a given bottom edge
#'
#' @param grob The footnote textGrob, or NULL.
#' @param y_bottom_npc Bottom edge of the footnote in npc units (outer_vp).
#'   With just = c(just, "bottom"), the bottom of the text aligns here.
#' @keywords internal
draw_footnote_section <- function(grob, y_bottom_npc) {
  if (!is.null(grob)) {
    grid::grid.draw(grid::editGrob(grob, y = grid::unit(y_bottom_npc, "npc")))
  }
}

#' Draw footer section (left, center, right grobs) at a given bottom edge
#'
#' @param grobs Named list from build_section_grobs(): footer_left,
#'   footer_center, footer_right.
#' @param y_bottom_npc Bottom edge of the footer row in npc units (outer_vp).
#' @keywords internal
draw_footer_section <- function(grobs, y_bottom_npc) {
  for (nm in c("footer_left", "footer_center", "footer_right")) {
    g <- grobs[[nm]]
    if (!is.null(g)) {
      grid::grid.draw(grid::editGrob(g, y = grid::unit(y_bottom_npc, "npc")))
    }
  }
}

#' Draw a rule grob at the vertical midpoint of a padding gap
#'
#' @param rule FALSE or a linesGrob (from normalize_rule()).
#' @param y_mid_npc Y midpoint of the padding gap in npc (outer_vp).
#' @keywords internal
draw_rule <- function(rule, y_mid_npc) {
  if (isFALSE(rule)) return(invisible(NULL))
  g <- grid::editGrob(rule, y = grid::unit(c(y_mid_npc, y_mid_npc), "npc"))
  grid::grid.draw(g)
}

#' Draw a figure (ggplot or future types) inside a viewport
#'
#' @param fig A ggplot object. Future: grob, recordedPlot.
#' @param vp A viewport object.
#' @keywords internal
#' @importFrom ggplot2 ggplot
draw_figure <- function(fig, vp) {
  if (inherits(fig, "ggplot")) {
    grid::pushViewport(vp)
    print(fig, newpage = FALSE)
    grid::popViewport()
  } else {
    # FUTURE: grob branch — grid::pushViewport(vp); grid::grid.draw(fig); grid::popViewport()
    # FUTURE: recordedPlot branch — grid::pushViewport(vp); grDevices::replayPlot(fig); grid::popViewport()
    rlang::abort("x$figure must be a ggplot object (other types not yet supported)")
  }
}
