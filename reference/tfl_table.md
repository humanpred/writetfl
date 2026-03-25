# Define a data frame table for PDF export

Creates a table configuration object that can be passed to
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md).
All measurement, pagination, and rendering are deferred until
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
is called, at which point page layout information (dimensions, margins,
annotations) is available.

Column properties can be specified via
[`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md)
objects in `cols`, via the flat arguments (`col_widths`, `col_labels`,
etc.), or both. When both name the same column,
[`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md)
takes priority.

Row-header columns (which repeat on every column-split page) are
detected automatically from `dplyr::group_vars(x)`. Group columns
**must** appear as the first columns of `x` in the same order as
`dplyr::group_vars(x)`; an error is raised if not.

## Usage

``` r
tfl_table(
  x,
  cols = NULL,
  col_widths = NULL,
  col_labels = NULL,
  col_align = NULL,
  wrap_cols = FALSE,
  min_col_width = grid::unit(0.5, "inches"),
  allow_col_split = TRUE,
  balance_col_pages = FALSE,
  suppress_repeated_groups = TRUE,
  col_cont_msg = c("Columns continue from prior page", "Columns continue to next page"),
  row_cont_msg = c("(continued)", "(continued on next page)"),
  show_col_names = TRUE,
  col_header_rule = TRUE,
  group_rule = TRUE,
  group_rule_after_last = FALSE,
  row_rule = FALSE,
  row_header_sep = FALSE,
  fill_by = "row",
  na_string = "",
  gp = list(),
  cell_padding = grid::unit(c(0.2, 0.5), "lines"),
  line_height = 1.05,
  max_measure_rows = Inf
)
```

## Arguments

- x:

  A data frame or grouped tibble (from
  [`dplyr::group_by()`](https://dplyr.tidyverse.org/reference/group_by.html)).

- cols:

  A list of
  [`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md)
  objects, or `NULL` to auto-specify all columns. When `cols` is
  provided it may be partial — columns not named in `cols` fall back to
  flat arguments or type-based defaults. Column display order always
  follows the source data frame, regardless of the order of entries in
  `cols`.

- col_widths:

  Named vector: each element is either a `unit` object (fixed width) or
  a plain positive numeric (relative weight). Names must match column
  names in `x`. Overridden per-column by `tfl_colspec(width)`.

- col_labels:

  Named character vector of display labels. Use `"\n"` for multiline
  column headers. Overridden per-column by `tfl_colspec(label)`.

- col_align:

  Named character vector. Each element is `"left"`, `"right"`, or
  `"centre"`. Overridden per-column by `tfl_colspec(align)`.

- wrap_cols:

  Column-wrapping eligibility. `TRUE` = all non-group columns eligible;
  `FALSE` = none eligible; character vector = those specific column
  names. Overridden per-column by `tfl_colspec(wrap)`.

- min_col_width:

  Minimum column width as a `unit` object.

- allow_col_split:

  Logical. If `FALSE`, an error is raised when total column width still
  exceeds available width after wrapping. If `TRUE` (default), columns
  are split across pages.

- balance_col_pages:

  Logical. When `TRUE` and column pagination produces more than one
  page, the data columns are redistributed across the pages so that each
  page receives approximately the same number of columns. The greedy
  pass is still used to determine the minimum number of pages required,
  and each balanced group is verified to fit; if a balanced group would
  overflow the available width the greedy layout is used as a fallback.
  Default `FALSE`.

- suppress_repeated_groups:

  Logical. When `TRUE` (default), group column cells whose value equals
  the immediately preceding rendered row on the same page are left
  blank. The first data row on each page always shows the group value.

- col_cont_msg:

  Character vector of length 1 or 2, or `NULL`. Rotated side labels on
  column-split pages. The first element is shown counter-clockwise 90°
  at the **left** edge of the viewport when columns continue from a
  prior page; the second element is shown clockwise 90° at the **right**
  edge when columns continue on a subsequent page. A length-1 value is
  recycled to both sides. When a column split is detected, column widths
  are recomputed to reserve half a character-height at each labelled
  edge so the table content does not overlap the annotation. Set to
  `NULL` to disable.

- row_cont_msg:

  Character vector of length 1 or 2. The first element is shown at the
  **top** of a continuation page; the second is shown at the **bottom**
  of the preceding page. A length-1 value is recycled to both positions.
  Default: `c("(continued)", "(continued on next page)")`.

- show_col_names:

  Logical. If `FALSE`, the column header row is omitted and
  `col_header_rule` is also suppressed.

- col_header_rule:

  Logical. If `TRUE` (default), a horizontal rule is drawn below the
  column header row.

- group_rule:

  Logical. If `TRUE` (default), a horizontal rule is drawn between row
  groups.

- group_rule_after_last:

  Logical. If `TRUE`, a rule is also drawn after the last group on a
  page. Default `FALSE`.

- row_rule:

  Logical. If `TRUE`, a horizontal rule is drawn between every data row.
  Style is controlled via `gp$row_rule`. Default `FALSE`.

- row_header_sep:

  Logical. If `TRUE`, a vertical rule is drawn at the right edge of the
  last row-header column, spanning data rows only (not the column header
  row). Default `FALSE`.

- fill_by:

  Character scalar controlling how `gp$data_row$fill` color vectors are
  cycled. `"row"` (default) advances the color index for every data row.
  `"group"` advances only at group boundaries, so all rows in the same
  group share one fill color.

- na_string:

  Character scalar. Replacement text for `NA` values. Default `""`.

- gp:

  A named list of [`gpar()`](https://rdrr.io/r/grid/gpar.html) objects
  controlling table-internal typography and rule styles. Page-annotation
  typography is controlled separately via the `gp` argument of
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).
  Recognised keys:

  `gp$table`

  :   Base font for all table text.

  `gp$header_row`

  :   Column header row. Default: bold. Set `fill` for a background
      color (e.g., `gpar(fontface = "bold", fill = "lightblue")`).

  `gp$data_row`

  :   Data cell text. Inherits `gp$table`. Set `fill` for background
      color; use a vector for alternating rows or groups (e.g.,
      `gpar(fill = c("white", "gray95"))`). See `fill_by`.

  `gp$group_col`

  :   Row-header column cells. Inherits `gp$table`.

  `gp$continued`

  :   Continuation-marker row text. Default: italic.

  `gp$col_header_rule`

  :   Style of the column-header rule.

  `gp$group_rule`

  :   Style of between-group rules.

  `gp$row_rule`

  :   Style of between-row data rules.

  `gp$row_header_sep`

  :   Style of the vertical row-header separator.

- cell_padding:

  Padding inside each cell. Accepts a `unit` of length:

  - 1: applied to all four sides

  - 2: `c(vertical, horizontal)` — first element for top/bottom, second
    for left/right

  - 4: `c(top, right, bottom, left)` — CSS-style per-side control

  Example: `unit(c(0.2, 0.5), "lines")` for 0.2 lines vertical, 0.5
  lines horizontal. Note: named vectors are not supported because
  [`grid::unit()`](https://rdrr.io/r/grid/unit.html) does not preserve
  names from numeric vectors.

- line_height:

  A positive numeric multiplier that controls the spacing between lines
  within a multi-line (word-wrapped) cell. A value of `1.0` packs lines
  baseline-to-baseline with no extra gap; the default `1.05` adds a
  small 5% breathing room. If a
  [`gpar()`](https://rdrr.io/r/grid/gpar.html) supplied through the `gp`
  argument already contains an explicit `lineheight` field for a
  particular section, that value takes precedence over this parameter.

- max_measure_rows:

  Positive numeric or `Inf` (default). Maximum number of unique cell
  strings sampled per column when computing content-based column widths.
  Strings are sampled in descending order of
  [`nchar()`](https://rdrr.io/r/base/nchar.html) so the widest strings
  are always measured. Also limits the number of data rows sampled for
  row-height estimation.

## Value

An object of class `"tfl_table"`. Pass directly to
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md).

## See also

[`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md),
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)

## Examples

``` r
if (FALSE) { # \dontrun{
library(dplyr)

df <- group_by(mtcars, cyl)

tbl <- tfl_table(
  df,
  col_labels = c(mpg = "MPG", hp = "Horse-\npower"),
  col_align  = c(mpg = "right", hp = "right"),
  wrap_cols  = FALSE
)

export_tfl(tbl,
           file          = "cars.pdf",
           header_left   = "Study XYZ",
           caption       = "Table 1. Motor Trend Cars",
           page_num      = "Page {i} of {n}")
} # }
```
