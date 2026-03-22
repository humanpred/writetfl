# Lay out and render a single TFL page

Renders a single page with up to five vertical sections: header,
caption, content, footnote, and footer. Section heights are computed
dynamically from font metrics so that the content area occupies all
remaining space. All layout errors (overlapping elements, content area
too short) are collected and reported together before any drawing
occurs.

## Usage

``` r
export_tfl_page(
  x,
  padding = grid::unit(0.5, "lines"),
  header_left = NULL,
  header_center = NULL,
  header_right = NULL,
  caption = NULL,
  footnote = NULL,
  footer_left = NULL,
  footer_center = NULL,
  footer_right = NULL,
  gp = grid::gpar(),
  header_rule = FALSE,
  footer_rule = FALSE,
  caption_just = "left",
  footnote_just = "left",
  margins = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  min_content_height = grid::unit(3, "inches"),
  page_i = NULL,
  preview = FALSE,
  ...
)
```

## Arguments

- x:

  A list with a required `content` element (a `ggplot` object or any
  grid grob, e.g. from `gt::as_gtable()` or `gridExtra::tableGrob()`)
  and optional text elements: `header_left`, `header_center`,
  `header_right`, `caption`, `footnote`, `footer_left`, `footer_center`,
  `footer_right`. List elements take precedence over the corresponding
  direct arguments.

- padding:

  Vertical space between adjacent present sections, as a `unit` object.
  Separator rules (if enabled) are drawn at the midpoint of this gap and
  do not consume additional space.

- header_left, header_center, header_right:

  Header text. Accepts `NULL`, a single string, or a character vector
  (collapsed with `"\\n"`). Horizontal justification follows the
  argument name (left/center/right). Vertically top-justified.
  Overridden by `x$header_left` etc.

- caption:

  Caption text below the header and above the content. Accepts `NULL`, a
  single string, or a character vector. Full-width; justification
  controlled by `caption_just`. Overridden by `x$caption`.

- footnote:

  Footnote text below the content. Accepts `NULL`, a single string, or a
  character vector. Full-width; justification controlled by
  `footnote_just`. Overridden by `x$footnote`.

- footer_left, footer_center, footer_right:

  Footer text. Mirror of header arguments. Vertically bottom-justified.
  Overridden by `x$footer_left` etc.

- gp:

  Typography specification. Accepts either a single
  [`gpar()`](https://rdrr.io/r/grid/gpar.html) object applied to all
  text, or a named list for section- or element-level control.
  Resolution priority (highest first): element-level (e.g.
  `gp$header_left`), section-level (e.g. `gp$header`), global
  [`gpar()`](https://rdrr.io/r/grid/gpar.html). Example:

      gp = list(
        header        = gpar(fontsize = 11, fontface = "bold"),
        header_right  = gpar(fontsize =  9, col = "gray50"),
        caption       = gpar(fontsize =  9, fontface = "italic"),
        footer        = gpar(fontsize =  8)
      )

- header_rule:

  Separator rule drawn between the header and the next section (caption
  or content), fitted within the `padding` gap. Accepts:

  - `FALSE`: no rule

  - `TRUE`: full-width rule

  - A numeric in `(0, 1]`: rule spanning that fraction of viewport
    width, centered

  - A grob (typically a `linesGrob`): drawn as-is, centered vertically
    in the padding gap.

- footer_rule:

  Separator rule between the last body section (footnote or content) and
  the footer. Same specification as `header_rule`.

- caption_just:

  Horizontal justification for the caption.

- footnote_just:

  Horizontal justification for the footnote.

- margins:

  Outer page margins as a `unit` vector with elements `t`, `r`, `b`, `l`
  (top, right, bottom, left).

- min_content_height:

  Minimum acceptable content area height as a `unit` object. An error is
  raised if the computed content height falls below this value.

- page_i:

  Integer page index, used to prefix layout error messages with
  `"Page <i>: "`. Set automatically by
  [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md);
  not normally supplied when calling this function directly.

- preview:

  Logical. If `TRUE`, calls
  [`grid.newpage()`](https://rdrr.io/r/grid/grid.newpage.html) and draws
  to the currently open device without opening or closing any device.

- ...:

  Additional arguments. Currently recognised:

  - `overlap_warn_mm`: numeric threshold in mm for near-miss overlap
    warnings. Set to `NULL` to disable.

## Value

Invisibly returns `NULL`.

## See also

[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
for multi-page PDF export.
