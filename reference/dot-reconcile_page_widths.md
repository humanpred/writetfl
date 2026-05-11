# Combine per-page width vectors into one per-column vector

Non-group columns appear on exactly one page-column-split page; their
final width is whatever that page allocated. Group columns repeat on
every page and must be drawn at a single width that satisfies every
page; under the `col_split_strategy = "balanced"` design they are pinned
at the minimum width across pages so data columns on every page receive
the most slack. This helper enforces both rules and returns a single
`numeric(n_cols)` vector with each column's final width.

## Usage

``` r
.reconcile_page_widths(per_page_widths, col_groups, n_group_cols, n_cols)
```

## Arguments

- per_page_widths:

  List of `numeric` vectors; element `g` is the per-column width vector
  for `col_groups[[g]]` (length equals `length(col_groups[[g]])`).

- col_groups:

  List of integer vectors of column indices per page-column-split page
  (as returned by
  [`paginate_cols()`](https://humanpred.github.io/writetfl/reference/paginate_cols.md)).

- n_group_cols:

  Integer scalar; the first `n_group_cols` column indices are group
  columns.

- n_cols:

  Total number of columns in the table.

## Value

Numeric vector of length `n_cols`.
