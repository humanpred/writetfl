# Group-aware greedy pagination for table1 flextables

Splits a table1-derived flextable across pages, keeping each variable's
label and summary statistic rows together. If a single variable group
exceeds the page height, falls back to row-by-row splitting within that
group.

## Usage

``` r
.paginate_table1(ft_obj, groups, content_h, content_w)
```

## Arguments

- ft_obj:

  A cleaned `flextable` (converted from table1, no footer rows).

- groups:

  List of integer vectors from
  [`.table1_variable_groups()`](https://humanpred.github.io/writetfl/reference/dot-table1_variable_groups.md).

- content_h:

  Available content height in inches.

- content_w:

  Available content width in inches.

## Value

A list of `flextable` objects (one per page).
