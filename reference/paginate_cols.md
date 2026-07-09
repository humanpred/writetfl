# Split data columns into groups that fit within content_width_in

Group columns (first n_group_cols) are always included in every group.
Data columns are greedily packed left-to-right in units of *atoms* (a
multi-column header span keeps its columns together; see
[`.data_atoms()`](https://humanpred.github.io/writetfl/reference/dot-data_atoms.md)).
When `balance_col_pages` is `TRUE` and the greedy pass produces more
than one page, atoms are redistributed so that each page receives
approximately the same number of atoms (while still verifying that each
balanced group fits within the available width).

## Usage

``` r
paginate_cols(
  widths_in,
  content_width_in,
  n_group_cols,
  allow_col_split,
  balance_col_pages = FALSE,
  spanned_gap = NULL
)
```

## Arguments

- spanned_gap:

  NULL or a logical vector (length `n_cols-1`) marking gaps covered by a
  multi-column header span; those gaps are never split.

## Value

List of integer vectors (column indices into resolved_cols).
