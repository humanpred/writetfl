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
  content_just = "left",
  margins = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  min_content_height = grid::unit(3, "inches"),
  overflow_action = c("error", "warn"),
  page_i = NULL,
  preview = FALSE,
  newpage = TRUE,
  ...
)
```

## Arguments

- x:

  A list with a required `content` element and optional text elements:
  `header_left`, `header_center`, `header_right`, `caption`, `footnote`,
  `footer_left`, `footer_center`, `footer_right`. `content` accepts a
  `ggplot` object, any grid grob (e.g. from
  [`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html)
  or `gridExtra::tableGrob()`), a character string, or a character
  vector (elements are joined with `"\\n"` and word-wrapped to the
  content viewport width). List elements take precedence over the
  corresponding direct arguments.

- padding:

  Vertical space between adjacent present sections, as a `unit` object.
  Separator rules (if enabled) are drawn at the midpoint of this gap and
  do not consume additional space.

- header_left, header_center, header_right:

  Header text. Accepts `NULL`, a single string, or a character vector
  (collapsed with `"\\n"`). A single `NA` is treated the same as `NULL`
  (section element absent), so that data-driven page construction can
  leave an element unset. Horizontal justification follows the argument
  name (left/center/right). Vertically top-justified. Overridden by
  `x$header_left` etc.

- caption:

  Caption text below the header and above the content. Accepts `NULL`, a
  single `NA` (treated as `NULL`), a single string, or a character
  vector. Full-width; justification controlled by `caption_just`.
  Overridden by `x$caption`.

- footnote:

  Footnote text below the content. Accepts `NULL`, a single `NA`
  (treated as `NULL`), a single string, or a character vector.
  Full-width; justification controlled by `footnote_just`. Overridden by
  `x$footnote`.

- footer_left, footer_center, footer_right:

  Footer text. Mirror of header arguments (a single `NA` is treated as
  `NULL`). Vertically bottom-justified. Overridden by `x$footer_left`
  etc.

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

  - `FALSE` (or a single `NA`): no rule

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

- content_just:

  Horizontal justification for character string content. One of `"left"`
  (default), `"right"`, or `"centre"`. Ignored when `x$content` is a
  ggplot or grob.

- margins:

  Outer page margins as a `unit` vector with elements `t`, `r`, `b`, `l`
  (top, right, bottom, left).

- min_content_height:

  Minimum acceptable content area height as a `unit` object. An error is
  raised if the computed content height falls below this value.

- overflow_action:

  One of `"error"` (default) or `"warn"`. Controls how width-overflow
  conditions are reported when the content does not fit in its allocated
  area:

  - `"error"`: append the message to the layout-error vector and abort
    before drawing (no PDF page is produced).

  - `"warn"`: emit
    [`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html) and
    continue rendering. The PDF is produced with the overflow visibly
    clipped by `grid`, which is useful for diagnosing what is too wide.
    See issue \#30.

  The same setting applies to all width-overflow detections: the
  page-level content grob check (any `grob` content wider than the
  content viewport), the
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  total-width check (when `allow_col_split = FALSE` and the column total
  still exceeds the page after wrapping), and the
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  per-column check (any single column — or any data column combined with
  the row-header group columns — wider than the page).

- page_i:

  Integer page index, used to prefix layout error messages with
  `"Page <i>: "`. A single `NA` is treated the same as `NULL` (no
  prefix). Set automatically by
  [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md);
  not normally supplied when calling this function directly.

- preview:

  Logical. If `TRUE`, calls
  [`grid.newpage()`](https://rdrr.io/r/grid/grid.newpage.html) and draws
  to the currently open device without opening or closing any device.

- newpage:

  Logical. If `TRUE` (default), start the page with
  [`grid.newpage()`](https://rdrr.io/r/grid/grid.newpage.html). If
  `FALSE`, draw onto the device's current page (after resetting the
  viewport stack to the root).
  [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
  sets `FALSE` for the first page in normal mode so that pagination
  measurement, which opens a blank page on the shared metric device,
  does not leave a spurious leading blank page. Not normally supplied
  when calling this function directly.

- ...:

  Arguments passed on to
  [`check_overlap`](https://humanpred.github.io/writetfl/reference/check_overlap.md),
  [`.convert_tabs`](https://humanpred.github.io/writetfl/reference/dot-convert_tabs.md)

  `overlap_warn_mm`

  :   Near-miss threshold in mm. NULL skips all detection.

  `tab_indent_spaces`

  :   Number of spaces a *leading* (indentation) tab — one preceded only
      by whitespace — is expanded to. Default `2`, matching the common
      "a tab indents by two spaces" convention.

  `tab_infix_spaces`

  :   Number of spaces an *in-line* tab — one with non-whitespace to its
      left — is expanded to. Default `1`; the resulting space then
      behaves as an ordinary breakable space.

## Value

Invisibly returns `NULL`.

## See also

[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
for multi-page PDF export.
