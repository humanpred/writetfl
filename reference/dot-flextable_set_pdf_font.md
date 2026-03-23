# Set PDF-compatible font on a flextable

Replaces any non-standard font families with `"Helvetica"` (a standard
PDF base font) to avoid "invalid font type" errors on the PDF device.

## Usage

``` r
.flextable_set_pdf_font(ft_obj)
```

## Arguments

- ft_obj:

  A `flextable` object.

## Value

The modified `flextable` object.
