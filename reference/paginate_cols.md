# Split data columns into groups that fit within content_width_in

Group columns (first n_group_cols) are always included in every group.
Data columns are greedily packed left-to-right. When `balance_col_pages`
is `TRUE` and the greedy pass produces more than one page, the data
columns are redistributed so that each page receives approximately the
same number of columns (while still verifying that each balanced group
fits within the available width).

## Usage

``` r
paginate_cols(
  widths_in,
  content_width_in,
  n_group_cols,
  allow_col_split,
  balance_col_pages = FALSE
)
```

## Value

List of integer vectors (column indices into resolved_cols).
