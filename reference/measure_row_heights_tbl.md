# Measure the rendered height of each data row in inches

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
  max_measure_rows
)
```

## Value

Numeric vector of row heights in inches (length = nrow(data)).
