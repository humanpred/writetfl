# Paginate an oversized variable group row-by-row

When a single variable group (label + summary rows) exceeds the
available content height, falls back to row-by-row greedy splitting.

## Usage

``` r
.paginate_oversized_group(ft_obj, grp_rows, content_h, content_w)
```

## Arguments

- ft_obj:

  The full flextable object.

- grp_rows:

  Integer vector of body row indices for the oversized group.

- content_h:

  Available content height in inches.

- content_w:

  Available content width in inches.

## Value

A list of objects. Complete sub-pages are `flextable` objects. The last
element is a list with `$body_rows` (integer vector of remaining row
indices) for further accumulation.
