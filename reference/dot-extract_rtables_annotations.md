# Extract annotations from a VTableTree object

Extracts main title + subtitles as caption and main footer + provenance
footer as footnote text.

## Usage

``` r
.extract_rtables_annotations(rt_obj)
```

## Arguments

- rt_obj:

  A `VTableTree` object.

## Value

A list with `$caption` (character or NULL) and `$footnote` (character or
NULL).
