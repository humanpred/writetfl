# Normalize rule specification to FALSE or a grob

Normalize rule specification to FALSE or a grob

## Usage

``` r
normalize_rule(x)
```

## Arguments

- x:

  FALSE, TRUE, numeric in (0,1\], or a grob. A single `NA` is treated
  the same as `FALSE` (no rule), so that data-driven construction can
  leave the toggle unset. A `linesGrob` is the typical choice, but any
  grob is accepted and will be drawn as-is (centered vertically in the
  padding gap).

## Value

FALSE or a grob.
