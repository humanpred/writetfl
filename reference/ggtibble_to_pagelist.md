# Convert a ggtibble object to a list of page specification lists

Each row of the ggtibble becomes one page spec. The `figure` column
provides the content (ggplot). Any columns whose names match
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
text arguments are used as per-page values.

## Usage

``` r
ggtibble_to_pagelist(x)
```

## Arguments

- x:

  A `ggtibble` object.

## Value

A list of page spec lists, each with at least `$content`.
