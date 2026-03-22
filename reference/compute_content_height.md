# Compute available content height after subtracting all other sections

Compute available content height after subtracting all other sections

## Usage

``` r
compute_content_height(vp_height_in, section_heights, present, padding_in)
```

## Arguments

- vp_height_in:

  Viewport (outer_vp) height in inches.

- section_heights:

  Named list: header, caption, footnote, footer (inches).

- present:

  Logical named vector: header, caption, content, footnote, footer.

- padding_in:

  Padding height in inches.

## Value

Numeric content height in inches.
