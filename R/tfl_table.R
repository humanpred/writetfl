# tfl_table.R — Table configuration constructor and print method

# ---------------------------------------------------------------------------
# tfl_colspec() — per-column property specification
# ---------------------------------------------------------------------------

#' Specify display properties for a single table column
#'
#' @description
#' Creates a column specification object for use with [tfl_table()]. All
#' arguments are optional — unspecified properties fall back to the
#' corresponding flat argument in `tfl_table()`, or to type-based defaults.
#'
#' You can use `tfl_colspec()` for fine-grained per-column control, or use the
#' flat arguments of `tfl_table()` (`col_widths`, `col_labels`, `col_align`,
#' `wrap_cols`) for simpler cases. When both are provided for the same column,
#' the `tfl_colspec()` entry takes priority.
#'
#' @param col Character scalar. Column name in the data frame passed to
#'   [tfl_table()].
#' @param label Character scalar or `NULL`. Display label for the column header.
#'   `NULL` uses the column name. Use `"\n"` for multiline headers.
#' @param width A `unit` object (e.g. `unit(1.5, "inches")`) or a plain
#'   positive numeric (treated as a relative weight; columns with relative
#'   weights are scaled to fill available width after fixed-width columns are
#'   placed). `NULL` triggers content-based auto-sizing.
#' @param align Character scalar: `"left"`, `"right"`, or `"centre"`. `NULL`
#'   defaults to `"right"` for numeric columns and `"left"` otherwise.
#' @param wrap Logical. Whether this column is eligible for word-wrapping when
#'   total column widths exceed available width.
#' @param gp A `gpar()` object to override [tfl_table()]'s `gp$group_col` for
#'   this specific column. Only valid for row-header (group) columns; an error
#'   is raised if applied to a data column.
#'
#' @return An object of class `"tfl_colspec"`.
#'
#' @seealso [tfl_table()]
#' @export
tfl_colspec <- function(col,
                        label  = NULL,
                        width  = NULL,
                        align  = NULL,
                        wrap   = FALSE,
                        gp     = NULL) {
  checkmate::assert_string(col, min.chars = 1, .var.name = "col")
  checkmate::assert_string(label, null.ok = TRUE, .var.name = "label")
  if (!is.null(width)) {
    if (!inherits(width, "unit") && !(is.numeric(width) && length(width) == 1L && width > 0)) {
      rlang::abort("`width` must be NULL, a positive numeric (relative weight), or a unit object.")
    }
  }
  if (!is.null(align)) {
    align <- match.arg(align, c("left", "right", "centre"))
  }
  checkmate::assert_flag(wrap, .var.name = "wrap")
  checkmate::assert_class(gp, "gpar", null.ok = TRUE, .var.name = "gp")

  structure(
    list(col = col, label = label, width = width,
         align = align, wrap = wrap, gp = gp),
    class = "tfl_colspec"
  )
}

# ---------------------------------------------------------------------------
# tfl_table() — table configuration constructor
# ---------------------------------------------------------------------------

#' Define a data frame table for PDF export
#'
#' @description
#' Creates a table configuration object that can be passed to [export_tfl()].
#' All measurement, pagination, and rendering are deferred until `export_tfl()`
#' is called, at which point page layout information (dimensions, margins,
#' annotations) is available.
#'
#' Column properties can be specified via `tfl_colspec()` objects in `cols`,
#' via the flat arguments (`col_widths`, `col_labels`, etc.), or both. When
#' both name the same column, `tfl_colspec()` takes priority.
#'
#' Row-header columns (which repeat on every column-split page) are detected
#' automatically from `dplyr::group_vars(x)`. Group columns **must** appear
#' as the first columns of `x` in the same order as `dplyr::group_vars(x)`;
#' an error is raised if not.
#'
#' @param x A data frame or grouped tibble (from [dplyr::group_by()]).
#' @param cols A list of [tfl_colspec()] objects, or `NULL` to auto-specify
#'   all columns. When `cols` is provided it may be partial — columns not
#'   named in `cols` fall back to flat arguments or type-based defaults.
#'   Column display order always follows the source data frame, regardless of
#'   the order of entries in `cols`.
#' @param col_widths Named vector: each element is either a `unit` object
#'   (fixed width) or a plain positive numeric (relative weight). Names must
#'   match column names in `x`. Overridden per-column by `tfl_colspec(width)`.
#' @param col_labels Named character vector of display labels. Use `"\n"` for
#'   multiline column headers. Overridden per-column by `tfl_colspec(label)`.
#' @param col_align Named character vector. Each element is `"left"`,
#'   `"right"`, or `"centre"`. Overridden per-column by `tfl_colspec(align)`.
#' @param wrap_cols Column-wrapping eligibility. `TRUE` = all non-group
#'   columns eligible; `FALSE` = none eligible; character vector = those
#'   specific column names. Overridden per-column by `tfl_colspec(wrap)`.
#' @param min_col_width Minimum column width as a `unit` object.
#' @param allow_col_split Logical. If `FALSE`, an error is raised when total
#'   column width still exceeds available width after wrapping. If `TRUE`
#'   (default), columns are split across pages.
#' @param balance_col_pages Logical. When `TRUE` and column pagination produces
#'   more than one page, the data columns are redistributed across the pages so
#'   that each page receives approximately the same number of columns. The
#'   greedy pass is still used to determine the minimum number of pages
#'   required, and each balanced group is verified to fit; if a balanced group
#'   would overflow the available width the greedy layout is used as a fallback.
#'   Default `FALSE`.
#' @param suppress_repeated_groups Logical. When `TRUE` (default), group column
#'   cells whose value equals the immediately preceding rendered row on the
#'   same page are left blank. The first data row on each page always shows
#'   the group value.
#' @param col_cont_msg Character vector of length 1 or 2, or `NULL`. Rotated
#'   side labels on column-split pages. The first element is shown
#'   counter-clockwise 90° at the **left** edge of the viewport when columns
#'   continue from a prior page; the second element is shown clockwise 90° at
#'   the **right** edge when columns continue on a subsequent page. A length-1
#'   value is recycled to both sides. Set to `NULL` to disable.
#' @param row_cont_msg Character vector of length 1 or 2. The first element is
#'   shown at the **top** of a continuation page; the second is shown at the
#'   **bottom** of the preceding page. A length-1 value is recycled to both
#'   positions. Default: `c("(continued)", "(continued on next page)")`.
#' @param show_col_names Logical. If `FALSE`, the column header row is omitted
#'   and `col_header_rule` is also suppressed.
#' @param col_header_rule Logical. If `TRUE` (default), a horizontal rule is
#'   drawn below the column header row.
#' @param group_rule Logical. If `TRUE` (default), a horizontal rule is drawn
#'   between row groups.
#' @param group_rule_after_last Logical. If `TRUE`, a rule is also drawn after
#'   the last group on a page. Default `FALSE`.
#' @param row_rule Logical. If `TRUE`, a horizontal rule is drawn between
#'   every data row. Style is controlled via `gp$row_rule`. Default `FALSE`.
#' @param row_header_sep Logical. If `TRUE`, a vertical rule is drawn at the
#'   right edge of the last row-header column, spanning data rows only (not
#'   the column header row). Default `FALSE`.
#' @param fill_by Character scalar controlling how `gp$data_row$fill` color
#'   vectors are cycled. `"row"` (default) advances the color index for every
#'   data row. `"group"` advances only at group boundaries, so all rows in the
#'   same group share one fill color.
#' @param na_string Character scalar. Replacement text for `NA` values.
#'   Default `""`.
#' @param gp A named list of `gpar()` objects controlling table-internal
#'   typography and rule styles. Page-annotation typography is controlled
#'   separately via the `gp` argument of [export_tfl_page()]. Recognised keys:
#'   \describe{
#'     \item{`gp$table`}{Base font for all table text.}
#'     \item{`gp$header_row`}{Column header row. Default: bold. Set `fill`
#'       for a background color (e.g.,
#'       `gpar(fontface = "bold", fill = "lightblue")`).}
#'     \item{`gp$data_row`}{Data cell text. Inherits `gp$table`. Set `fill`
#'       for background color; use a vector for alternating rows or groups
#'       (e.g., `gpar(fill = c("white", "gray95"))`). See `fill_by`.}
#'     \item{`gp$group_col`}{Row-header column cells. Inherits `gp$table`.}
#'     \item{`gp$continued`}{Continuation-marker row text. Default: italic.}
#'     \item{`gp$col_header_rule`}{Style of the column-header rule.}
#'     \item{`gp$group_rule`}{Style of between-group rules.}
#'     \item{`gp$row_rule`}{Style of between-row data rules.}
#'     \item{`gp$row_header_sep`}{Style of the vertical row-header separator.}
#'   }
#' @param cell_padding Padding inside each cell. Accepts a `unit` of length:
#'   - 1: applied to all four sides
#'   - 2: `c(vertical, horizontal)` — first element for top/bottom, second for
#'     left/right
#'   - 4: `c(top, right, bottom, left)` — CSS-style per-side control
#'
#'   Example: `unit(c(0.2, 0.5), "lines")` for 0.2 lines vertical, 0.5 lines
#'   horizontal. Note: named vectors are not supported because `grid::unit()`
#'   does not preserve names from numeric vectors.
#' @param line_height A positive numeric multiplier that controls the spacing
#'   between lines within a multi-line (word-wrapped) cell. A value of `1.0`
#'   packs lines baseline-to-baseline with no extra gap; the default `1.05`
#'   adds a small 5% breathing room. If a `gpar()` supplied through the `gp`
#'   argument already contains an explicit `lineheight` field for a particular
#'   section, that value takes precedence over this parameter.
#' @param max_measure_rows Positive numeric or `Inf` (default). Maximum number
#'   of unique cell strings sampled per column when computing content-based
#'   column widths. Strings are sampled in descending order of `nchar()` so
#'   the widest strings are always measured. Also limits the number of data
#'   rows sampled for row-height estimation.
#'
#' @return An object of class `"tfl_table"`. Pass directly to [export_tfl()].
#'
#' @seealso [tfl_colspec()], [export_tfl()]
#'
#' @examples
#' \dontrun{
#' library(dplyr)
#'
#' df <- group_by(mtcars, cyl)
#'
#' tbl <- tfl_table(
#'   df,
#'   col_labels = c(mpg = "MPG", hp = "Horse-\npower"),
#'   col_align  = c(mpg = "right", hp = "right"),
#'   wrap_cols  = FALSE
#' )
#'
#' export_tfl(tbl,
#'            file          = "cars.pdf",
#'            header_left   = "Study XYZ",
#'            caption       = "Table 1. Motor Trend Cars",
#'            page_num      = "Page {i} of {n}")
#' }
#'
#' @importFrom dplyr group_vars
#' @importFrom rlang "%||%"
#' @export
tfl_table <- function(x,
                      cols                     = NULL,
                      col_widths               = NULL,
                      col_labels               = NULL,
                      col_align                = NULL,
                      wrap_cols                = FALSE,
                      min_col_width            = grid::unit(0.5, "inches"),
                      allow_col_split          = TRUE,
                      balance_col_pages        = FALSE,
                      suppress_repeated_groups = TRUE,
                      col_cont_msg             = c("Columns continue from prior page",
                                                    "Columns continue to next page"),
                      row_cont_msg             = c("(continued)", "(continued on next page)"),
                      show_col_names           = TRUE,
                      col_header_rule          = TRUE,
                      group_rule               = TRUE,
                      group_rule_after_last    = FALSE,
                      row_rule                 = FALSE,
                      row_header_sep           = FALSE,
                      fill_by                  = "row",
                      na_string                = "",
                      gp                       = list(),
                      cell_padding             = grid::unit(c(0.2, 0.5), "lines"),
                      line_height              = 1.05,
                      max_measure_rows         = Inf) {

  # --- Validate x ---
  checkmate::assert_data_frame(x, min.cols = 1, .var.name = "x")

  grp_vars <- dplyr::group_vars(x)

  # Group columns must be a prefix of names(x) in order
  if (length(grp_vars) > 0L) {
    expected_prefix <- names(x)[seq_along(grp_vars)]
    if (!identical(grp_vars, expected_prefix)) {
      rlang::abort(paste0(
        "Group columns must be the first columns of `x` in the same order ",
        "as `dplyr::group_vars(x)`.\n",
        "  group_vars: ", paste(grp_vars, collapse = ", "), "\n",
        "  first cols: ", paste(expected_prefix, collapse = ", ")
      ))
    }
  }

  col_names <- names(x)

  # --- Validate cols list ---
  if (!is.null(cols)) {
    if (!is.list(cols)) {
      rlang::abort("`cols` must be NULL or a list of tfl_colspec() objects.")
    }
    for (i in seq_along(cols)) {
      if (!inherits(cols[[i]], "tfl_colspec")) {
        rlang::abort(paste0("`cols[[", i, "]]` must be a tfl_colspec() object."))
      }
      spec_col <- cols[[i]]$col
      if (!spec_col %in% col_names) {
        rlang::abort(paste0(
          "tfl_colspec column \"", spec_col, "\" not found in `x`. ",
          "Available columns: ", paste(col_names, collapse = ", ")
        ))
      }
      # gp on non-group column is an error
      if (!is.null(cols[[i]]$gp) && !spec_col %in% grp_vars) {
        rlang::abort(paste0(
          "tfl_colspec `gp` is only valid for row-header (group) columns. ",
          "\"", spec_col, "\" is not a group column."
        ))
      }
    }
  }

  # --- Validate flat col args ---
  .check_named_subset(col_widths, col_names, "col_widths")
  .check_named_subset(col_labels, col_names, "col_labels", require_character = TRUE)
  .check_named_subset(col_align, col_names, "col_align", require_character = TRUE)
  if (!is.null(col_align)) {
    bad_vals <- setdiff(col_align, c("left", "right", "centre"))
    if (length(bad_vals) > 0L) {
      bad_cols <- names(col_align)[col_align %in% bad_vals]
      rlang::abort(paste0(
        'col_align values must be "left", "right", or "centre". ',
        "Invalid values: ", paste(bad_vals, collapse = ", "),
        " (in columns: ", paste(bad_cols, collapse = ", "), ")"
      ))
    }
  }

  # --- Validate wrap_cols ---
  if (!is.logical(wrap_cols) && !is.character(wrap_cols)) {
    rlang::abort('`wrap_cols` must be TRUE, FALSE, or a character vector of column names.')
  }
  if (is.character(wrap_cols)) {
    bad <- setdiff(wrap_cols, col_names)
    if (length(bad) > 0L) {
      rlang::abort(paste0("wrap_cols names not found in `x`: ",
                          paste(bad, collapse = ", ")))
    }
  }

  # --- Validate min_col_width ---
  checkmate::assert_class(min_col_width, "unit", .var.name = "min_col_width")

  # --- Validate cell_padding and normalise to 4-element named vector ---
  cell_padding <- .normalise_cell_padding(cell_padding)

  # --- Validate scalar logicals ---
  checkmate::assert_flag(allow_col_split,          .var.name = "allow_col_split")
  checkmate::assert_flag(balance_col_pages,        .var.name = "balance_col_pages")
  checkmate::assert_flag(suppress_repeated_groups, .var.name = "suppress_repeated_groups")
  checkmate::assert_flag(show_col_names,           .var.name = "show_col_names")
  checkmate::assert_flag(col_header_rule,          .var.name = "col_header_rule")
  checkmate::assert_flag(group_rule,               .var.name = "group_rule")
  checkmate::assert_flag(group_rule_after_last,    .var.name = "group_rule_after_last")
  checkmate::assert_flag(row_rule,                 .var.name = "row_rule")
  checkmate::assert_flag(row_header_sep,           .var.name = "row_header_sep")
  fill_by <- match.arg(fill_by, c("row", "group"))

  # --- Validate messages ---
  checkmate::assert_character(col_cont_msg, min.len = 1L, max.len = 2L,
                              null.ok = TRUE, .var.name = "col_cont_msg")
  if (!is.null(col_cont_msg)) col_cont_msg <- rep(col_cont_msg, length.out = 2L)
  checkmate::assert_character(row_cont_msg, min.len = 1, max.len = 2,
                              .var.name = "row_cont_msg")
  row_cont_msg <- rep(row_cont_msg, length.out = 2L)
  checkmate::assert_string(na_string, .var.name = "na_string")

  # --- Validate gp ---
  if (!is.list(gp) && !inherits(gp, "gpar")) {
    rlang::abort("`gp` must be a list of gpar() objects (named by section) or a single gpar().")
  }

  # --- Validate line_height ---
  checkmate::assert_number(line_height, lower = .Machine$double.eps,
                           finite = TRUE, .var.name = "line_height")

  # --- Validate max_measure_rows ---
  checkmate::assert_number(max_measure_rows, lower = 1,
                           .var.name = "max_measure_rows")

  structure(
    list(
      data                     = x,
      group_vars               = grp_vars,
      cols                     = cols,
      col_widths               = col_widths,
      col_labels               = col_labels,
      col_align                = col_align,
      wrap_cols                = wrap_cols,
      min_col_width            = min_col_width,
      allow_col_split          = allow_col_split,
      balance_col_pages        = balance_col_pages,
      suppress_repeated_groups = suppress_repeated_groups,
      col_cont_msg             = col_cont_msg,
      row_cont_msg             = row_cont_msg,
      show_col_names           = show_col_names,
      col_header_rule          = col_header_rule,
      group_rule               = group_rule,
      group_rule_after_last    = group_rule_after_last,
      row_rule                 = row_rule,
      row_header_sep           = row_header_sep,
      fill_by                  = fill_by,
      na_string                = na_string,
      gp                       = gp,
      cell_padding             = cell_padding,
      line_height              = line_height,
      max_measure_rows         = max_measure_rows
    ),
    class = "tfl_table"
  )
}

# ---------------------------------------------------------------------------
# print.tfl_table()
# ---------------------------------------------------------------------------

#' Print a tfl_table object
#'
#' Displays a compact summary of the table configuration.
#'
#' @param x A `tfl_table` object.
#' @param ... Ignored.
#' @return Invisibly returns `x`.
#' @export
print.tfl_table <- function(x, ...) {
  d        <- x$data
  n_rows   <- nrow(d)
  n_cols   <- ncol(d)
  grp      <- x$group_vars
  n_grp    <- length(grp)
  n_data   <- n_cols - n_grp

  cat("<tfl_table>\n")
  cat(sprintf("  Data: %d row%s x %d col%s",
              n_rows, if (n_rows == 1L) "" else "s",
              n_cols, if (n_cols == 1L) "" else "s"))
  if (n_grp > 0L) {
    cat(sprintf("  (%d row-header col%s: %s)",
                n_grp, if (n_grp == 1L) "" else "s",
                paste(grp, collapse = ", ")))
  }
  cat("\n")

  # Column summary
  resolved <- .resolve_col_specs_preview(x)
  cat("  Columns:\n")
  for (cs in resolved) {
    width_str <- if (is.null(cs$width)) {
      "auto"
    } else if (inherits(cs$width, "unit")) {
      paste0(round(.width_in(cs$width), 2), " in")
    } else {
      paste0("rel(", cs$width, ")")
    }
    type_tag <- if (cs$col %in% grp) " [row-header]" else ""
    cat(sprintf("    %-20s  label=%-20s  width=%-10s  align=%s%s\n",
                cs$col,
                paste0('"', cs$label, '"'),
                width_str,
                cs$align %||% "auto",
                type_tag))
  }

  # Wrap columns
  wc <- x$wrap_cols
  if (isTRUE(wc)) {
    cat("  Wrap: all columns\n")
  } else if (is.character(wc) && length(wc) > 0L) {
    cat(sprintf("  Wrap: %s\n", paste(wc, collapse = ", ")))
  }

  # Key options
  cat("  Options:\n")
  cat(sprintf("    allow_col_split=%s  suppress_repeated_groups=%s  show_col_names=%s\n",
              x$allow_col_split, x$suppress_repeated_groups, x$show_col_names))
  cat(sprintf("    col_header_rule=%s  group_rule=%s  row_rule=%s  row_header_sep=%s\n",
              x$col_header_rule, x$group_rule, x$row_rule, x$row_header_sep))
  if (!is.null(x$col_cont_msg)) {
    cat(sprintf("    col_cont_msg: left=\"%s\"  right=\"%s\"\n",
                x$col_cont_msg[[1L]], x$col_cont_msg[[2L]]))
  }

  # Approximate page count (rough heuristic: ~30 rows per page)
  est_row_pages <- max(1L, ceiling(n_rows / 30))
  cat(sprintf("  Approx. pages: ~%d (rough estimate)\n", est_row_pages))

  invisible(x)
}

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

# Normalise cell_padding to a named list of 4 individual unit objects:
# list(top = unit, right = unit, bottom = unit, left = unit)
# This guarantees [["top"]] etc. always work, regardless of grid unit internals.
#
# NOTE: grid::unit() does NOT preserve names from named numeric vectors
# (known grid limitation; see CLAUDE.md). Detection is length-based only:
#   Length 1  -> scalar, apply to all 4 sides
#   Length 2  -> positional: [1] = vertical (top/bottom), [2] = horizontal (left/right)
#   Any other -> error
.normalise_cell_padding <- function(cp) {
  if (!inherits(cp, "unit")) {
    rlang::abort("`cell_padding` must be a unit object.")
  }
  len <- length(cp)

  if (len == 1L) {
    return(list(top = cp, right = cp, bottom = cp, left = cp))
  }

  if (len == 2L) {
    v <- cp[1L]   # vertical   (top / bottom)
    h <- cp[2L]   # horizontal (left / right)
    return(list(top = v, right = h, bottom = v, left = h))
  }

  if (len == 4L) {
    return(list(top = cp[1L], right = cp[2L], bottom = cp[3L], left = cp[4L]))
  }

  rlang::abort(paste0(
    "`cell_padding` must be a unit of length 1 (all sides), 2 (vertical, ",
    "horizontal), or 4 (top, right, bottom, left)."
  ))
}

# Validate that a named argument's names are a subset of valid_names.
# Optionally require the argument to be a character vector.
# Does nothing when arg is NULL.
.check_named_subset <- function(arg, valid_names, arg_name,
                                require_character = FALSE) {
  if (is.null(arg)) return(invisible(NULL))
  if (require_character && !is.character(arg)) {
    rlang::abort(paste0("`", arg_name, "` must be a named character vector."))
  }
  if (is.null(names(arg))) {
    rlang::abort(paste0("`", arg_name, "` must be a named vector."))
  }
  bad <- setdiff(names(arg), valid_names)
  if (length(bad) > 0L) {
    rlang::abort(paste0(arg_name, " names not found in `x`: ",
                        paste(bad, collapse = ", ")))
  }
  invisible(NULL)
}

# Safe lookup in a named vector/list: returns NULL if key absent (unlike [[)
.nlookup <- function(x, key) {
  if (is.null(x) || !key %in% names(x)) NULL else x[[key]]
}

# Lightweight column-spec preview for print method (no measurement)
.resolve_col_specs_preview <- function(tbl) {
  col_names  <- names(tbl$data)
  # Index tfl_colspec entries by col name
  spec_index <- if (!is.null(tbl$cols)) {
    stats::setNames(tbl$cols, vapply(tbl$cols, `[[`, "", "col"))
  } else list()

  lapply(col_names, function(cn) {
    spec   <- spec_index[[cn]]
    label  <- spec$label  %||% .nlookup(tbl$col_labels, cn) %||% cn
    width  <- spec$width  %||% .nlookup(tbl$col_widths,  cn)
    align  <- spec$align  %||% .nlookup(tbl$col_align,   cn)
    list(col = cn, label = label, width = width, align = align)
  })
}
