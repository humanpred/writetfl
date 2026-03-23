# Extract annotations from a gt_tbl object

Extracts title + subtitle as caption and source notes + footnotes as
footnote text.

## Usage

``` r
.extract_gt_annotations(gt_obj)
```

## Arguments

- gt_obj:

  A `gt_tbl` object.

## Value

A list with `$caption` (character or NULL) and `$footnote` (character or
NULL).
