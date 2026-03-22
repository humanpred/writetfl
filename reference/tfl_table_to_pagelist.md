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
  page_num = "Page {i} of {n}",
  for_preview = FALSE
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

- page_num:

  Glue template string for page numbering.

- for_preview:

  If `TRUE`, scratch devices used for text measurement match the current
  (raster) device's font metrics instead of using a PDF device. This
  prevents text clipping when column widths are measured for preview
  rendering.

## Value

A list of page spec lists, each with at least `$content` (a grob).
