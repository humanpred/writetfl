# Greedy row pagination for flextable

Incrementally adds body rows, measures the sub-table height, and splits
when a page would overflow.

## Usage

``` r
.paginate_flextable(ft_obj, content_h, content_w)
```

## Arguments

- ft_obj:

  A cleaned `flextable` (no footer rows).

- content_h:

  Available content height in inches.

- content_w:

  Available content width in inches.

## Value

A list of `flextable` objects (one per page).
