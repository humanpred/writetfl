# Convert a flextable object to a list of page specification lists

Extracts caption and footer-row footnotes from the flextable, removes
the footer rows to avoid duplication, then renders via
[`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html).

## Usage

``` r
flextable_to_pagelist(
  ft_obj,
  pg_width = 11,
  pg_height = 8.5,
  dots = list(),
  page_num = "Page {i} of {n}"
)
```

## Arguments

- ft_obj:

  A `flextable` object.

- pg_width, pg_height:

  Page dimensions in inches.

- dots:

  Named list of additional arguments from `...`.

- page_num:

  Glue template for page numbering (used for height calc).

## Value

A list of page spec lists, each with at least `$content`.

## Details

When the rendered table exceeds the available content height, rows are
split across multiple pages using greedy pagination.
