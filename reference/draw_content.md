# Draw the page content (ggplot, grob, or character string) inside a viewport

Draw the page content (ggplot, grob, or character string) inside a
viewport

## Usage

``` r
draw_content(content, vp, gp = grid::gpar(), content_just = "left", ...)
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

- ...:

  Arguments passed on to
  [`.convert_tabs`](https://humanpred.github.io/writetfl/reference/dot-convert_tabs.md)

  `tab_indent_spaces`

  :   Number of spaces a *leading* (indentation) tab — one preceded only
      by whitespace — is expanded to. Default `2`, matching the common
      "a tab indents by two spaces" convention.

  `tab_infix_spaces`

  :   Number of spaces an *in-line* tab — one with non-whitespace to its
      left — is expanded to. Default `1`; the resulting space then
      behaves as an ordinary breakable space.
