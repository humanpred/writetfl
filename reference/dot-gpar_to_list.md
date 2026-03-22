# Convert a gpar to a plain list, restoring fontface as a character string

`gpar(fontface = "bold")` stores `font = 2L` internally and loses the
string. This helper reconstructs `fontface` so downstream merging can
preserve the string form (required for `$fontface` access on the
result).

## Usage

``` r
.gpar_to_list(g)
```
