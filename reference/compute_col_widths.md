# Compute final column widths and column groups

Compute final column widths and column groups

## Usage

``` r
compute_col_widths(
  resolved_cols,
  data,
  content_width_in,
  tbl,
  pg_width,
  pg_height,
  margins
)
```

## Value

A list with `$resolved_cols` (widths_in filled in) and `$col_groups`
(list of integer vectors of column indices per group).
