# Specify display properties for a single table column

Creates a column specification object for use with
[`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md).
All arguments are optional — unspecified properties fall back to the
corresponding flat argument in
[`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md),
or to type-based defaults.

You can use `tfl_colspec()` for fine-grained per-column control, or use
the flat arguments of
[`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
(`col_widths`, `col_labels`, `col_align`, `wrap_cols`) for simpler
cases. When both are provided for the same column, the `tfl_colspec()`
entry takes priority.

## Usage

``` r
tfl_colspec(
  col,
  label = NULL,
  width = NULL,
  align = NULL,
  wrap = NA,
  gp = NULL
)
```

## Arguments

- col:

  Character scalar. Column name in the data frame passed to
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md).

- label:

  Character scalar or `NULL`. Display label for the column header.
  `NULL` uses the column name. Use `"\n"` for multiline headers.

- width:

  A `unit` object (e.g. `unit(1.5, "inches")`) or a plain positive
  numeric (treated as a relative weight; columns with relative weights
  are scaled to fill available width after fixed-width columns are
  placed). `NULL` triggers content-based auto-sizing.

- align:

  Character scalar: `"left"`, `"right"`, or `"centre"`. `NULL` defaults
  to `"right"` for numeric columns and `"left"` otherwise.

- wrap:

  Logical of length 1: `TRUE`, `FALSE`, or `NA`. Controls text-wrapping
  eligibility *within this column*. `NA` (the default) means "inherit
  from the table-level
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)'s
  `wrap_cols` setting"; under the default `wrap_cols = "auto"` that
  resolves to `TRUE` when any cell or the header contains a break
  character (see `wrap_breaks`). `TRUE` / `FALSE` are explicit
  overrides. This is **text wrap** inside a column; for splitting a
  too-wide table across pages see `allow_col_split` in
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md).

- gp:

  A [`gpar()`](https://rdrr.io/r/grid/gpar.html) object to override
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)'s
  `gp$group_col` for this specific column. Only valid for row-header
  (group) columns; an error is raised if applied to a data column.

## Value

An object of class `"tfl_colspec"`.

## See also

[`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
