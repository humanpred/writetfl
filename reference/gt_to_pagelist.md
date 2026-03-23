# Convert a gt_tbl object to a list of page specification lists

Extracts title, subtitle, source notes, and footnotes from the gt object
into writetfl annotation fields (caption, footnote), removes them from
the gt object to avoid duplication, and converts the table body to a
grid grob via
[`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html).

## Usage

``` r
gt_to_pagelist(
  gt_obj,
  pg_width = 11,
  pg_height = 8.5,
  dots = list(),
  page_num = "Page {i} of {n}"
)
```

## Arguments

- gt_obj:

  A `gt_tbl` object.

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
split across multiple pages respecting row group boundaries.
