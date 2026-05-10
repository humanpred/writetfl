# Does any string in `strings` contain a break character?

Used by the `wrap_cols = "auto"` path: a column with no breakable text
is skipped because no amount of narrowing can wrap it.

## Usage

``` r
.column_has_breakable_text(strings, breaks)
```
