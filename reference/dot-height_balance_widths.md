# Redistribute widths between wrap-eligible columns to lower total height

Opt-in pass triggered by `tfl_table(wrap_balance = "height")`. Runs
after
[`.compute_wrapped_widths()`](https://humanpred.github.io/writetfl/reference/dot-compute_wrapped_widths.md)
(water-fill) and uses a bounded greedy local search: at each iteration
find the row whose cells are tallest, identify the wrap-eligible column
that drives that row's height (the "bottleneck") and the wrap-eligible
column with the most slack (shortest cell content in that row, with room
to give up width down to its floor), and try transferring a width delta
from slack to bottleneck. Accept the move that reduces the *total table
height* (sum of per-row heights, plus header). Stop when no transfer at
any tested delta improves total height, when `max_iter` is reached, or
when `budget_seconds` of wall-time is exhausted.

## Usage

``` r
.height_balance_widths(
  widths_in,
  resolved_cols,
  data,
  tbl,
  h_pad_in,
  na_str,
  max_rows,
  breaks,
  pg_width,
  pg_height,
  margins,
  budget_seconds = 1,
  max_iter = 20L
)
```

## Details

Cell heights at each `(column, width)` pair are cached so repeat
measurements during the search are free; with cell-string deduplication
inside one column, the total measurement cost is bounded by
`n_unique_cells * n_unique_widths_explored` per column.

Invariants:

- Total width is preserved exactly (every move is a transfer).

- No column shrinks below its floor (the larger of `min_col_width` and
  the rendered width of its longest unbreakable token under either the
  cell or header gpar).

- No column grows past its natural width (max content width including
  bold-rendered header tokens).

- Any error or invariant violation falls back silently to the input
  widths, so opting in cannot produce a *worse* table than the default.

Approximation: the cost function ignores the rowspan-style group-cell
suppression handled by `.compute_page_row_heights()` - group columns are
typically not wrap-eligible (auto-detect skips them), so they don't
participate in moves; the approximation only marginally affects which
move is "best" when group columns happen to dominate a row's height.
