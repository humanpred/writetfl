# Convert a VTableTree object to a list of page specification lists

Extracts main title + subtitles as caption and main footer + provenance
footer as footnote, strips them from the rtables object to avoid
duplication, then renders via
[`toString()`](https://insightsengineering.github.io/formatters/latest-tag/reference/tostring.html)
into a `textGrob`.

## Usage

``` r
rtables_to_pagelist(
  rt_obj,
  pg_width = 11,
  pg_height = 8.5,
  dots = list(),
  page_num = "Page {i} of {n}"
)
```

## Arguments

- rt_obj:

  A `VTableTree` object.

- pg_width, pg_height:

  Page dimensions in inches.

- dots:

  Named list of additional arguments from `...`.

- page_num:

  Glue template for page numbering (used for height calc).

## Value

A list of page spec lists, each with at least `$content`.

## Details

When the table exceeds the available content height, rtables' built-in
[`paginate_table()`](https://insightsengineering.github.io/rtables/latest-tag/reference/paginate.html)
splits it across pages respecting row group boundaries.
