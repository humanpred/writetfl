# table_utils.R — Internal helpers shared across table_pagelist, table_columns,
#                 table_rows, and table_draw.
#
# Functions:
#   .make_outer_vp()              — construct the margins viewport
#   .measure_header_row_height()  — height of the column header row
#   .measure_cont_row_height()    — height of a continuation-marker row
#   .gp_with_lineheight()         — inject lineheight into a gpar (respects overrides)
#   .compute_group_starts()       — row indices where a new group begins
#   .compute_group_sizes()        — number of rows per group
#   .collect_col_strings()        — unique strings for a column (header + data)
#   .fmt_cell()                   — format a single cell value (NA → na_string)
#   .fmt_cell_vec()               — vectorised version of .fmt_cell()
#   .measure_max_string_width()   — max rendered text width in inches
#   .resolve_table_gp()           — gpar for a named table section
#   .resolve_table_cell_gp()      — gpar for a data or group cell
#   .default_align()              — type-based default alignment
#   .wrap_text()                  — greedy word-wrap to a width in inches

# ---------------------------------------------------------------------------
# Viewport helpers
# ---------------------------------------------------------------------------

# Build outer_vp — shared by export_tfl_page() and table_* measurement code.
# Uses unit arithmetic so that margins in any unit (inches, lines, mm, etc.)
# are resolved correctly against the current device.
.make_outer_vp <- function(margins) {
  mt <- margins[1L]; mr <- margins[2L]; mb <- margins[3L]; ml <- margins[4L]
  grid::viewport(
    x      = ml,
    y      = mb,
    width  = grid::unit(1, "npc") - ml - mr,
    height = grid::unit(1, "npc") - mt - mb,
    just   = c("left", "bottom"),
    name   = "outer_vp"
  )
}

# ---------------------------------------------------------------------------
# Row height measurement helpers
# ---------------------------------------------------------------------------

# Measure column header row height (max across all column labels)
.measure_header_row_height <- function(resolved_cols, gp_tbl, cell_padding,
                                       line_height) {
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  hdr_gp   <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "header_row"),
                                   line_height)

  max(vapply(resolved_cols, function(cs) {
    nlines <- max(1L, length(strsplit(cs$label, "\n", fixed = TRUE)[[1L]]))
    grob   <- grid::textGrob(cs$label, gp = hdr_gp)
    h_grob <- .height_in(grid::grobHeight(grob))
    h_line <- nlines * .height_in(grid::stringHeight("M"))
    max(h_grob, h_line)
  }, numeric(1L))) + v_pad_in
}

# Measure height of a continuation-marker row
.measure_cont_row_height <- function(row_cont_msg, gp_tbl, cell_padding,
                                     line_height) {
  v_pad_in <- .height_in(cell_padding[["top"]]) +
              .height_in(cell_padding[["bottom"]])
  cont_gp  <- .gp_with_lineheight(.resolve_table_gp(gp_tbl, "continued"),
                                   line_height)
  grob     <- grid::textGrob(row_cont_msg, gp = cont_gp)
  h_grob   <- .height_in(grid::grobHeight(grob))
  h_line   <- .height_in(grid::stringHeight("M"))
  max(h_grob, h_line) + v_pad_in
}

# ---------------------------------------------------------------------------
# gpar helpers
# ---------------------------------------------------------------------------

# Return a gpar identical to `gp` but with lineheight set to `lh`, unless the
# gpar already carries an explicit lineheight — in which case that value wins.
.gp_with_lineheight <- function(gp, lh) {
  fields <- as.list(gp)
  if (is.null(fields$lineheight)) {
    fields$lineheight <- lh
  }
  do.call(grid::gpar, fields)
}

# ---------------------------------------------------------------------------
# Group boundary helpers
# ---------------------------------------------------------------------------

# Identify row indices that start a new group
.compute_group_starts <- function(data, group_vars) {
  if (length(group_vars) == 0L || nrow(data) == 0L) return(integer(0L))
  n <- nrow(data)
  starts <- 1L
  for (i in seq_len(n - 1L)) {
    for (gv in group_vars) {
      if (!identical(data[[gv]][i], data[[gv]][i + 1L])) {
        starts <- c(starts, i + 1L)
        break
      }
    }
  }
  starts
}

# Compute group sizes (number of rows per group) from data and group vars.
# Returns a named integer vector: name = row index of group start (as string),
# value = number of rows in that group.
.compute_group_sizes <- function(data, group_vars) {
  if (length(group_vars) == 0L || nrow(data) == 0L) return(integer(0L))
  all_starts <- .compute_group_starts(data, group_vars)
  ends       <- c(all_starts[-1L] - 1L, nrow(data))
  sizes      <- ends - all_starts + 1L
  stats::setNames(sizes, as.character(all_starts))
}

# ---------------------------------------------------------------------------
# String / cell formatting helpers
# ---------------------------------------------------------------------------

# Format a single cell value, replacing NA
.fmt_cell <- function(val, na_string) {
  if (is.na(val)) na_string else as.character(val)
}

# Format a vector of cell values
.fmt_cell_vec <- function(vec, na_string) {
  ifelse(is.na(vec), na_string, as.character(vec))
}

# Collect unique strings for a column (header + data), limited by max_rows
.collect_col_strings <- function(col_vec, label, na_string, max_rows) {
  data_strs <- unique(.fmt_cell_vec(col_vec, na_string))
  # Sort descending by nchar and take top max_rows
  if (is.finite(max_rows) && length(data_strs) > max_rows) {
    data_strs <- data_strs[order(nchar(data_strs), decreasing = TRUE)[
      seq_len(max_rows)]]
  }
  c(strsplit(label, "\n", fixed = TRUE)[[1L]], data_strs)
}

# ---------------------------------------------------------------------------
# Unit conversion helpers
# ---------------------------------------------------------------------------

# Convert a grid unit to inches (width context).
.width_in <- function(x) grid::convertWidth(x, "inches", valueOnly = TRUE)

# Convert a grid unit to inches (height context).
.height_in <- function(x) grid::convertHeight(x, "inches", valueOnly = TRUE)

# ---------------------------------------------------------------------------
# Text measurement helpers
# ---------------------------------------------------------------------------

# Measure the maximum rendered text width (in inches) for a vector of strings.
# Uses textGrob rather than stringWidth() because stringWidth() does not
# accept a gp argument in all grid versions.
.measure_max_string_width <- function(strings, gp) {
  if (length(strings) == 0L) return(0)
  max(vapply(strings, function(s) {
    lines <- strsplit(s, "\n", fixed = TRUE)[[1L]]
    max(vapply(lines, function(ln) {
      grob <- grid::textGrob(ln, gp = gp)
      .width_in(grid::grobWidth(grob))
    }, numeric(1L)))
  }, numeric(1L)))
}

# Word-wrap a string to fit within available_w_in inches.
# Preserves explicit \n (paragraph breaks) and greedily breaks on spaces.
# Must be called while a viewport with the target font context is active.
.wrap_text <- function(text, available_w_in, gp) {
  if (!nzchar(text)) return(text)

  paragraphs <- strsplit(text, "\n", fixed = TRUE)[[1L]]

  wrapped_pars <- vapply(paragraphs, function(para) {
    if (!nzchar(para)) return("")
    words <- strsplit(para, " ")[[1L]]
    words <- words[nzchar(words)]
    if (length(words) == 0L) return("")

    lines        <- character(0L)
    current_line <- words[[1L]]

    for (k in seq_along(words)[-1L]) {
      test <- paste0(current_line, " ", words[[k]])
      w    <- .width_in(grid::grobWidth(grid::textGrob(test, gp = gp)))
      if (w > available_w_in + 1e-6) {
        lines        <- c(lines, current_line)
        current_line <- words[[k]]
      } else {
        current_line <- test
      }
    }
    paste(c(lines, current_line), collapse = "\n")
  }, character(1L))

  paste(wrapped_pars, collapse = "\n")
}

# ---------------------------------------------------------------------------
# gpar resolution helpers
# ---------------------------------------------------------------------------

# Resolve table-level gp key (with inheritance from gp$table)
.resolve_table_gp <- function(gp_list, key) {
  base     <- if (inherits(gp_list, "gpar")) gp_list else
              gp_list[["table"]] %||% grid::gpar()
  override <- if (is.list(gp_list)) gp_list[[key]] else NULL

  defaults <- list(
    header_row     = grid::gpar(fontface = "bold"),
    continued      = grid::gpar(fontface = "italic"),
    col_header_rule = grid::gpar(lwd = 1),
    group_rule     = grid::gpar(lwd = 0.5, lty = "dotted"),
    row_header_sep = grid::gpar(lwd = 0.5)
  )

  result <- merge_gpar(base, defaults[[key]] %||% grid::gpar())
  if (!is.null(override)) result <- merge_gpar(result, override)
  result
}

# Resolve gp for a table cell (group col or data col)
.resolve_table_cell_gp <- function(gp_list, is_group_col) {
  key <- if (is_group_col) "group_col" else "data_row"
  .resolve_table_gp(gp_list, key)
}

# ---------------------------------------------------------------------------
# Alignment helper
# ---------------------------------------------------------------------------

# Default alignment by column type
.default_align <- function(col_vec) {
  if (is.numeric(col_vec)) "right" else "left"
}
