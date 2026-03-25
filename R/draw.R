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

#' Draw the page content (ggplot, grob, or character string) inside a viewport
#'
#' @param content A ggplot object, any grid grob (including gtable), or a
#'   character string / character vector.  A character vector is collapsed with
#'   `"\\n"` before rendering, and long lines are word-wrapped to the viewport
#'   width.
#' @param vp A viewport object.
#' @param gp A `gpar()` object controlling typography for character content.
#'   Ignored for ggplot and grob content.
#' @param content_just Horizontal justification for character content:
#'   `"left"`, `"right"`, or `"centre"`.  Ignored for ggplot and grob content.
#' @keywords internal
#' @importFrom ggplot2 ggplot
draw_content <- function(content, vp, gp = grid::gpar(), content_just = "left") {
  if (inherits(content, "ggplot")) {
    grid::pushViewport(vp)
    print(content, newpage = FALSE)
    grid::popViewport()
  } else if (inherits(content, "grob")) {
    grid::pushViewport(vp)
    grid::grid.draw(content)
    grid::popViewport()
  } else if (is.character(content)) {
    x_npc <- switch(content_just, left = 0, right = 1, centre = 0.5)
    grid::pushViewport(vp)
    text    <- paste(content, collapse = "\n")
    avail_w <- .width_in(grid::unit(1, "npc"))
    wrapped <- .wrap_text(text, avail_w, gp)
    g <- grid::textGrob(
      label = wrapped,
      x     = grid::unit(x_npc, "npc"),
      y     = grid::unit(1, "npc"),
      just  = c(content_just, "top"),
      gp    = gp
    )
    grid::grid.draw(g)
    grid::popViewport()
  } else {
    # FUTURE: recordedPlot — grid::pushViewport(vp); grDevices::replayPlot(content); grid::popViewport()
    rlang::abort(paste(
      "x$content must be a ggplot object, a grid grob, or a character string/vector",
      "(e.g. from gt::as_gtable(), gridExtra::tableGrob())."
    ))
  }
}
