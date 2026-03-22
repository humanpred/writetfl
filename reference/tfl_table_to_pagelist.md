# Convert a tfl_table object to a list of page specification lists

Called internally by
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
when `x` is a `"tfl_table"`.

## Usage

``` r
tfl_table_to_pagelist(
  tbl,
  pg_width,
  pg_height,
  dots,
  page_num = "Page {i} of {n}"
)
```

## Arguments

- tbl:

  A `"tfl_table"` object.

- pg_width, pg_height:

  Page dimensions in inches.

- dots:

  The `list(...)` from
  [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md).

## Value

A list of page spec lists, each with at least `$content` (a grob).
