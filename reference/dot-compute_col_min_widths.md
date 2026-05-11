# Per-column minimum survivable width in inches

For wrap-eligible columns, the minimum is
`max(min_col_width, longest_unbreakable_token + h_pad)`, measured under
both the cell and header gpars and taking the larger so a bold-rendered
header token cannot be undersized. For non-wrap-eligible columns the
minimum equals the supplied `widths_natural` (those columns cannot
shrink without overflowing).

## Usage

``` r
.compute_col_min_widths(
  widths_natural,
  resolved_cols,
  data,
  tbl,
  h_pad_in,
  min_in,
  pg_width,
  pg_height,
  margins
)
```

## Arguments

- widths_natural:

  Numeric vector of per-column natural widths (inches). Used as the
  floor for non-wrap-eligible columns.

- resolved_cols:

  The
  [`resolve_col_specs()`](https://humanpred.github.io/writetfl/reference/resolve_col_specs.md)
  output.

- data:

  The full data frame from `tbl$data`.

- tbl:

  A `tfl_table` object (used for `gp`, `cell_padding`, `line_height`,
  `na_string`, `max_measure_rows`, `min_col_width`, `wrap_breaks`).

- h_pad_in:

  Horizontal cell padding (left+right) in inches.

- min_in:

  `min_col_width` resolved to inches.

- pg_width, pg_height, margins:

  Forwarded to the scratch device.

## Value

Numeric vector of per-column minimum widths in inches.

## Details

Opens its own scratch PDF device and outer viewport for measurement.
