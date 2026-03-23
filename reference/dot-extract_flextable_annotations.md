# Extract annotations from a flextable object

Extracts caption from
[`set_caption()`](https://davidgohel.github.io/flextable/reference/set_caption.html)
and footnote text from footer rows (added via
[`footnote()`](https://davidgohel.github.io/flextable/reference/footnote.html)
or
[`add_footer_lines()`](https://davidgohel.github.io/flextable/reference/add_footer_lines.html)).

## Usage

``` r
.extract_flextable_annotations(ft_obj)
```

## Arguments

- ft_obj:

  A `flextable` object.

## Value

A list with `$caption` (character or NULL) and `$footnote` (character or
NULL).
