# Measure a flextableGrob's height

flextableGrob does not support standard
[`grobHeight()`](https://rdrr.io/r/grid/grobWidth.html) measurement.
Instead, the total height is available from the grob's `ftpar$heights`
attribute, which contains per-row heights in inches.

## Usage

``` r
.flextable_grob_height(grob)
```

## Arguments

- grob:

  A `flextableGrob` from
  [`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html).

## Value

Numeric scalar: grob height in inches.
