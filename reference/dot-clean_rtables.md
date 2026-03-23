# Remove annotations from a VTableTree object

Strips main title, subtitles, main footer, and provenance footer so that
[`toString()`](https://insightsengineering.github.io/formatters/latest-tag/reference/tostring.html)
renders only the table body.

## Usage

``` r
.clean_rtables(rt_obj)
```

## Arguments

- rt_obj:

  A `VTableTree` object.

## Value

A cleaned `VTableTree` object.
