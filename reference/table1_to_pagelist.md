# Convert a table1 object to a list of page specification lists

Extracts caption and footnote from the table1 object's internal
structure, converts to a flextable via
[`table1::t1flex()`](https://rdrr.io/pkg/table1/man/t1flex.html), then
renders via
[`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html).
When the rendered table exceeds the available content height, rows are
split across multiple pages using group-aware pagination that keeps each
variable's label and summary statistics together.

## Usage

``` r
table1_to_pagelist(
  t1_obj,
  pg_width = 11,
  pg_height = 8.5,
  dots = list(),
  page_num = "Page {i} of {n}"
)
```

## Arguments

- t1_obj:

  A `table1` object.

- pg_width, pg_height:

  Page dimensions in inches.

- dots:

  Named list of additional arguments from `...`.

- page_num:

  Glue template for page numbering (used for height calc).

## Value

A list of page spec lists, each with at least `$content`.
