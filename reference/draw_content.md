# Draw the page content (ggplot, grob, or character string) inside a viewport

Draw the page content (ggplot, grob, or character string) inside a
viewport

## Usage

``` r
draw_content(content, vp, gp = grid::gpar(), content_just = "left")
```

## Arguments

- content:

  A ggplot object, any grid grob (including gtable), or a character
  string / character vector. A character vector is collapsed with
  `"\\n"` before rendering, and long lines are word-wrapped to the
  viewport width.

- vp:

  A viewport object.

- gp:

  A [`gpar()`](https://rdrr.io/r/grid/gpar.html) object controlling
  typography for character content. Ignored for ggplot and grob content.

- content_just:

  Horizontal justification for character content: `"left"`, `"right"`,
  or `"centre"`. Ignored for ggplot and grob content.
