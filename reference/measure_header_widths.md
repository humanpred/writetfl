# Measure widths of header left/center/right grobs

Returns NULL for absent (NULL) grobs so overlap detection can
distinguish absent from zero-width.

## Usage

``` r
measure_header_widths(grobs)
```

## Arguments

- grobs:

  Named list from build_section_grobs() — expects header_left,
  header_center, header_right.

## Value

Named list: left, center, right (numeric inches or NULL).
