# Build a text grob from a normalized text input

Build a text grob from a normalized text input

## Usage

``` r
build_text_grob(norm, resolved_gp, x_npc, just)
```

## Arguments

- norm:

  Output of normalize_text().

- resolved_gp:

  Output of resolve_gp() for this element.

- x_npc:

  Horizontal position in npc (0, 0.5, or 1).

- just:

  Justification vector passed to textGrob (e.g. c("left", "top")).

## Value

A textGrob or NULL if norm\$text is NULL.
