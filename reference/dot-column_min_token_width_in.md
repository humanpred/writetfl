# Width (inches) of the widest unbreakable token across a column's strings.

This is the wrapping floor: a column cannot be narrowed below the width
needed to render its longest single token.

## Usage

``` r
.column_min_token_width_in(strings, gp, breaks)
```
