# Convert a gt_tbl object to a list of page specification lists

Extracts title, subtitle, source notes, and footnotes from the gt object
into writetfl annotation fields (caption, footnote), removes them from
the gt object to avoid duplication, and converts the table body to a
grid grob via
[`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html).

## Usage

``` r
gt_to_pagelist(gt_obj)
```

## Arguments

- gt_obj:

  A `gt_tbl` object.

## Value

A list of page spec lists, each with at least `$content`.
