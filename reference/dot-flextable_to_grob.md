# Render a flextable to a grob via gen_grob()

Sets column widths proportionally to fit the available content width,
ensures a PDF-compatible font is used, then calls
[`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html)
with `fit = "width"` and top-left justification.

## Usage

``` r
.flextable_to_grob(ft_obj, content_w)
```

## Arguments

- ft_obj:

  A `flextable` object.

- content_w:

  Available content width in inches.

## Value

A `flextableGrob` (inherits from `gTree`).
