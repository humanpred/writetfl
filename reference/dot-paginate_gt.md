# Greedily assign row groups to pages

Measures the gtable height of cumulative row subsets and splits when a
page would overflow.

## Usage

``` r
.paginate_gt(cleaned_gt, content_h, pg_width, pg_height)
```

## Arguments

- cleaned_gt:

  A cleaned `gt_tbl` (no annotations).

- content_h:

  Available content height in inches.

- pg_width, pg_height:

  Page dimensions for scratch device.

## Value

A list of integer vectors (row indices per page).
