# Measure the rendered height of each table cell in inches

Must be called while a viewport is active. Uses a memoised string-height
function to avoid re-measuring repeated values.

## Usage

``` r
measure_row_heights_tbl(
  data,
  resolved_cols,
  gp_tbl,
  cell_padding,
  na_string,
  line_height,
  max_measure_rows,
  breaks = NULL,
  wrap_extra_pad_in = 0,
  cache = NULL
)
```

## Arguments

- max_measure_rows:

  Maximum number of rows to measure individually. Non-sampled rows take
  the per-column max of the sampled rows (a conservative estimate that
  mirrors prior behaviour).

## Value

Numeric matrix `[nrow(data) × length(resolved_cols)]` of inches.

## Details

Returns a matrix of cell heights (rows = data rows, cols =
resolved_cols). Each entry is the rendered height of that cell in
inches, **including the top + bottom cell padding (`v_pad_in`)** so that
the per-row height is simply `max(cell_h_mat[i, ])` without further
adjustment.
