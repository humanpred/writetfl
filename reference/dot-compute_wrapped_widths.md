# Iteratively narrow wrap-eligible columns to fit `content_width_in`.

Replaces the older single-target `.apply_col_wrapping()` with a fairer
"water-from-top" pass: each iteration finds the widest set of
wrap-eligible columns above their floor and shrinks them together until
the next-lower competitor or a floor is hit. Floors honour
`min_col_width` AND the longest unbreakable token in the column.

## Usage

``` r
.compute_wrapped_widths(
  widths_in,
  resolved_cols,
  data,
  tbl,
  content_width_in,
  h_pad_in,
  min_in,
  pg_width,
  pg_height,
  margins
)
```

## Arguments

- widths_in:

  Numeric vector of current per-column widths in inches.

- resolved_cols:

  The
  [`resolve_col_specs()`](https://humanpred.github.io/writetfl/reference/resolve_col_specs.md)
  output.

- data:

  The full data frame from `tbl$data`.

- tbl:

  A `tfl_table` object (used for `gp`, `cell_padding`, `line_height`,
  `na_string`, `max_measure_rows`, `min_col_width`, `wrap_breaks`).

- content_width_in:

  Numeric target total width in inches.

- h_pad_in:

  Horizontal padding (left+right) in inches.

- min_in:

  `min_col_width` resolved to inches.

- pg_width, pg_height, margins:

  Forwarded to the scratch device.

## Value

Updated `widths_in`.

## Details

Deterministic, O(n^2) in column count, n \<= ~30 in practice.
