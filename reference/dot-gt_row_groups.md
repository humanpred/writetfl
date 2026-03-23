# Extract row group boundaries from a gt object

Returns a list of integer vectors, each containing row indices for one
group. If no row groups are defined, each row is its own "group".

## Usage

``` r
.gt_row_groups(gt_obj)
```

## Arguments

- gt_obj:

  A `gt_tbl` object (already cleaned).

## Value

A list of integer vectors.
