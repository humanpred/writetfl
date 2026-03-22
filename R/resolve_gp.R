# resolve_gp.R — gpar hierarchy resolution
# See ARCHITECTURE.md for full contracts and merge_gpar() spec.

# Mapping between grid's integer font codes and fontface strings.
.font_to_face <- c("plain", "bold", "italic", "bold.italic", "symbol")

#' Convert a gpar to a plain list, restoring fontface as a character string
#'
#' `gpar(fontface = "bold")` stores `font = 2L` internally and loses the
#' string.  This helper reconstructs `fontface` so downstream merging can
#' preserve the string form (required for `$fontface` access on the result).
#' @keywords internal
.gpar_to_list <- function(g) {
  lst <- as.list(g)
  if (!is.null(lst$font) && is.numeric(lst$font)) {
    idx <- as.integer(lst$font)
    if (idx >= 1L && idx <= length(.font_to_face)) {
      lst$fontface <- .font_to_face[[idx]]
    }
    lst$font <- NULL
  }
  lst
}

#' Merge two gpar objects field-by-field, override wins
#' @keywords internal
merge_gpar <- function(base, override) {
  bl <- .gpar_to_list(base)
  ol <- .gpar_to_list(override)
  merged <- c(bl, ol)
  # fromLast = TRUE keeps the last (override) occurrence of duplicated names
  merged <- merged[!duplicated(names(merged), fromLast = TRUE)]
  # Store as a gpar-classed list; fontface kept as string so $fontface works.
  # Do NOT add font (integer) alongside fontface — grid rejects having both.
  structure(merged, class = "gpar")
}

#' Resolve gp for a specific section/element from the gp hierarchy
#'
#' @param gp A gpar() or named list.
#' @param section One of "header", "caption", "figure", "footnote", "footer".
#' @param element One of "header_left", "header_center", "header_right",
#'   "caption", "footnote", "footer_left", "footer_center", "footer_right".
#' @return A gpar() object.
#' @keywords internal
resolve_gp <- function(gp, section, element) {
  # Build up from lowest to highest priority, overwriting field-by-field.
  # Priority (lowest → highest): gpar() default → global gpar → section → element

  result <- grid::gpar()

  # Level 3: global — if gp itself is a bare gpar()
  if (inherits(gp, "gpar")) {
    result <- merge_gpar(result, gp)
    return(result)  # bare gpar has no section/element sub-keys
  }

  # gp is a list; walk up the hierarchy
  if (is.list(gp)) {
    # Section level
    section_gp <- gp[[section]]
    if (!is.null(section_gp) && inherits(section_gp, "gpar")) {
      result <- merge_gpar(result, section_gp)
    }

    # Element level (highest priority)
    element_gp <- gp[[element]]
    if (!is.null(element_gp) && inherits(element_gp, "gpar")) {
      result <- merge_gpar(result, element_gp)
    }
  }

  result
}
