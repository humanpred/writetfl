# Rebuild a gt object from a row index subset

Creates a new `gt_tbl` from the subset of rows, preserving column
labels, row groups, options, spanners, formatting, and styles.

## Usage

``` r
.rebuild_gt_subset(gt_obj, row_indices)
```

## Arguments

- gt_obj:

  A `gt_tbl` object (already cleaned of annotations).

- row_indices:

  Integer vector of row indices to keep.

## Value

A new `gt_tbl` object containing only the specified rows.
