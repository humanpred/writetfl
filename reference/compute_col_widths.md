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
  margins,
  overflow_action = c("error", "warn"),
  validate_overflow = TRUE
)
```

## Arguments

- overflow_action:

  One of `"error"` (default) or `"warn"`. Controls how width-overflow
  conditions are reported. See
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).

- validate_overflow:

  Logical (internal). When `FALSE`, skip the per-column / group-aware /
  total-width overflow checks. The second `cw_adj` pass in
  `.tfl_table_to_pagelist_default()` sets this to `FALSE` so the same
  overflow is not re-signalled on every pass.

## Value

A list with `$resolved_cols` (widths_in filled in) and `$col_groups`
(list of integer vectors of column indices per group).
