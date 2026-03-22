# Resolve column specifications into a unified per-column list

Returns a list (one element per column in source order) where each
element is a named list: col, label, width (unit/numeric/NULL), align,
wrap, gp (gpar or NULL), is_group_col.

## Usage

``` r
resolve_col_specs(tbl)
```
