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
  text_dim_cache = NULL
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

- text_dim_cache:

  Optional environment used as the pagination-phase text-dimension
  cache. When supplied, the same env is reused instead of allocating one
  locally, so the caller
  ([`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md))
  can later reuse its entries during the drawing phase by attaching the
  env to the table grobs. When `NULL` (the default), a fresh env is
  allocated and discarded after pagination completes – equivalent to the
  pre-D-48 behaviour.

## Value

A list of page spec lists, each with at least `$content` (a grob).
