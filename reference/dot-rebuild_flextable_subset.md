# Rebuild a flextable from a row index subset

Creates a new flextable from the subset of body rows, preserving the
header structure and column widths. Per-cell formatting applied via
[`color()`](https://davidgohel.github.io/flextable/reference/color.html),
[`bg()`](https://davidgohel.github.io/flextable/reference/bg.html),
[`bold()`](https://davidgohel.github.io/flextable/reference/bold.html),
etc. is NOT preserved.

## Usage

``` r
.rebuild_flextable_subset(ft_obj, row_indices)
```

## Arguments

- ft_obj:

  A `flextable` object (already cleaned of footer rows).

- row_indices:

  Integer vector of body row indices to keep.

## Value

A new `flextable` object containing only the specified rows.
