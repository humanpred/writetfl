# Split rows into pages, respecting group boundaries

Uses a per-page tentative recompute of `.compute_page_row_heights()` so
that span-aware row heights drive the page-fit decision. Two non-obvious
properties of this scheme are preserved by the algorithm:

## Usage

``` r
paginate_rows(
  data,
  cell_h_mat,
  resolved_cols,
  group_vars,
  cont_row_h,
  header_row_h,
  content_height_in,
  row_cont_msg,
  group_rule,
  suppress_repeated_groups = TRUE,
  overflow_action = "error",
  collect_overflows = FALSE
)
```

## Arguments

- data:

  Data frame.

- cell_h_mat:

  Per-cell height matrix from
  [`measure_row_heights_tbl()`](https://humanpred.github.io/writetfl/reference/measure_row_heights_tbl.md).

- resolved_cols:

  Full list of resolved column specs (used to identify non-group
  columns).

- group_vars:

  Character vector of group column names.

- cont_row_h:

  Height of a continuation-marker row in inches.

- header_row_h:

  Height of the column header row (0 if suppressed).

- content_height_in:

  Available content height per page.

- row_cont_msg:

  Text for continuation-marker rows.

- group_rule:

  Logical — are group rules drawn? (Reserved for future use; currently
  does not affect pagination because rules are 0-height.)

- suppress_repeated_groups:

  Logical, from `tbl$suppress_repeated_groups`.

- overflow_action:

  One of `"error"` (default) or `"warn"`. Controls how the row-overflow
  guard reports a single row whose committed height exceeds the
  available page content height (a row that wraps to taller than one
  page is almost always a sign of input that needs to change). The same
  knob downgrades column-overflow events; see
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).
  Ignored when `collect_overflows = TRUE`.

- collect_overflows:

  Logical. When `FALSE` (default) the function behaves as before:
  row-overflow events are routed through `overflow_action`. When `TRUE`
  the function does *not* signal on overflow but instead collects the
  events and returns them alongside the page specs, so a caller can
  iterate (see the row-overflow retry loop in
  `.tfl_table_to_pagelist_default()`).

## Value

When `collect_overflows = FALSE` (default), a list of row-page specs,
each with `$rows`, `$is_cont_top`, `$is_cont_bottom`, `$group_starts`,
and `$row_heights_in` (the committed per-row heights for that page in
inches). When `collect_overflows = TRUE`, a 2-element list: `$pages` (as
above) and `$overflows` (a list of overflow events, each
`list(row, bottleneck_col, cell_height_in)`; empty if no row
overflowed).

## Details

- Adding a row to an existing group-span on the current page may leave
  the total page height unchanged (the span absorbs deficit that
  previously inflated earlier rows), so more rows can fit than a per-row
  scalar sum would predict.

- When only the first row of a multi-row group lands on the current page
  (group orphan), that row's span on the page is length 1 and the row is
  grown to fit the full label height. `committed_rh` snapshots heights
  after each successful append, so the orphan-correct heights are what
  gets flushed to the page spec.
