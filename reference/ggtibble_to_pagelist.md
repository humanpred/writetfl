# Convert a ggtibble object to a list of page specification lists

Each row of the ggtibble becomes one page spec. The `figure` column
provides the content (ggplot). Any columns whose names match
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
text arguments are used as per-page values. When `sub_tfl` is supplied,
those columns' values are appended to each row's caption.

## Usage

``` r
ggtibble_to_pagelist(
  x,
  sub_tfl = NULL,
  sub_tfl_sep = ": ",
  sub_tfl_collapse = "; ",
  sub_tfl_prefix = "\n"
)
```

## Arguments

- x:

  A `ggtibble` object.

- sub_tfl:

  Character vector of column names in `x`, or `NULL`.

- sub_tfl_sep, sub_tfl_collapse, sub_tfl_prefix:

  Formatting controls for the appended `label: value` suffix. See
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md).

## Value

A list of page spec lists, each with at least `$content`.
