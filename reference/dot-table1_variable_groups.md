# Identify variable-group row boundaries in a table1 object

Each variable in a table1 output forms a "group" consisting of a bold
variable-label row followed by indented summary-statistic rows. This
function returns the flextable body row indices for each group, derived
from the `contents` matrices in the table1 object's internal structure.

## Usage

``` r
.table1_variable_groups(t1_obj)
```

## Arguments

- t1_obj:

  A `table1` object.

## Value

A list of integer vectors, each containing the body row indices for one
variable group (label row + summary rows).
