# Remove annotations from a gt_tbl object

Strips title, subtitle, source notes, and footnotes so that
[`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html)
renders only the table body.

## Usage

``` r
.clean_gt(gt_obj)
```

## Arguments

- gt_obj:

  A `gt_tbl` object.

## Value

A cleaned `gt_tbl` object.
