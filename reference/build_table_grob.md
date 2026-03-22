# Build a grid grob for one page of a tfl_table

Build a grid grob for one page of a tfl_table

## Usage

``` r
build_table_grob(
  row_page,
  col_group_idx,
  n_group_cols,
  resolved_cols,
  tbl,
  row_heights_in = NULL,
  cont_row_h_in = NULL,
  is_first_col_page = TRUE,
  is_last_col_page = TRUE
)
```

## Arguments

- row_page:

  List from paginate_rows(): \$rows, \$is_cont_top, \$is_cont_bottom,
  \$group_starts.

- col_group_idx:

  Integer vector of column indices (1-based into resolved_cols) for this
  column group, including row-header columns first.

- n_group_cols:

  Number of row-header (group) columns.

- resolved_cols:

  Full list of resolved column specs (all columns).

- tbl:

  The tfl_table object.

## Value

A gTree of class "tfl_table_grob".
