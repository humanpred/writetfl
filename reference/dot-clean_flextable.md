# Remove footer rows from a flextable object

Strips footer rows so that
[`gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html)
renders only the header and body. Footer text has already been extracted
into writetfl's footnote zone.

## Usage

``` r
.clean_flextable(ft_obj)
```

## Arguments

- ft_obj:

  A `flextable` object.

## Value

A cleaned `flextable` object.
