# Extract annotations from a table1 object

Extracts caption and footnote from the internal `"obj"` attribute of a
table1 object.

## Usage

``` r
.extract_table1_annotations(t1_obj)
```

## Arguments

- t1_obj:

  A `table1` object.

## Value

A list with `$caption` (character or NULL) and `$footnote` (character or
NULL).
