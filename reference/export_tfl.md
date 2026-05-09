# Export a list of TFLs to a multi-page PDF

Opens a PDF device, renders each page using
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md),
and closes the device. Guarantees device closure via
[`on.exit()`](https://rdrr.io/r/base/on.exit.html) even if an error
occurs during rendering.

When `preview` is not `FALSE`, no PDF is written. Instead the selected
pages are drawn to the currently open graphics device (useful in
RStudio, Positron, or knitr chunks) and returned as a list of grid
grobs.

## Usage

``` r
export_tfl(
  x,
  file = NULL,
  pg_width = 11,
  pg_height = 8.5,
  page_num = "Page {i} of {n}",
  preview = FALSE,
  ...
)
```

## Arguments

- x:

  A single `ggplot` object, a grid grob (e.g. from
  [`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html)
  or `gridExtra::tableGrob()`), a
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  object, a `ggtibble` object (from the ggtibble package), a `gt_tbl`
  object (from the gt package), a list of `gt_tbl` objects, or a named
  list of page specifications. Each page specification is a list with a
  required `content` element (a `ggplot` or grob) and optional elements
  corresponding to the text arguments of
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md):
  `header_left`, `header_center`, `header_right`, `caption`, `footnote`,
  `footer_left`, `footer_center`, `footer_right`. Per-page list elements
  take precedence over values supplied via `...`.

  When `x` is a
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  object, pagination and grob construction are performed automatically.
  Page layout arguments (`pg_width`, `pg_height`, and any arguments in
  `...` such as `margins`, `padding`, and annotations) are used both to
  compute available space and to render each page.

  When `x` is a `ggtibble` object, each row becomes a page. The `figure`
  column provides the content; any columns whose names match
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
  text arguments (`caption`, `footnote`, `header_left`, etc.) are used
  as per-page values. Other columns are ignored.

  When `x` is a `gt_tbl` object, the title and subtitle are extracted as
  the caption, source notes and footnotes are extracted as the footnote,
  and the table body is rendered as a grid grob via
  [`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html).
  A list of `gt_tbl` objects produces one page (or more, with
  pagination) per table.

  When `x` is a `VTableTree` object (from the rtables package), the main
  title and subtitles are extracted as the caption, and main footer and
  provenance footer are extracted as the footnote. The table is rendered
  as monospace text via
  [`toString()`](https://insightsengineering.github.io/formatters/latest-tag/reference/tostring.html)
  and wrapped in a grid `textGrob`. Pagination uses rtables' built-in
  [`paginate_table()`](https://insightsengineering.github.io/rtables/latest-tag/reference/paginate.html).
  A list of `VTableTree` objects produces one page (or more, with
  pagination) per table.

  When `x` is a `flextable` object (from the flextable package), the
  caption (from
  [`flextable::set_caption()`](https://davidgohel.github.io/flextable/reference/set_caption.html))
  is extracted as the caption, and footer rows (from
  [`flextable::footnote()`](https://davidgohel.github.io/flextable/reference/footnote.html)
  or
  [`flextable::add_footer_lines()`](https://davidgohel.github.io/flextable/reference/add_footer_lines.html))
  are extracted as the footnote. The table is rendered via
  [`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html).
  A list of `flextable` objects produces one page (or more, with
  pagination) per table.

  When `x` is a `table1` object (from the table1 package), the caption
  and footnote are extracted from the table1 object's internal
  structure. The table is converted to a flextable via
  [`table1::t1flex()`](https://rdrr.io/pkg/table1/man/t1flex.html),
  preserving column labels, bold variable names, and indented summary
  statistics. Pagination is group-aware: page breaks fall between
  variable groups (label + summary rows) rather than splitting a group
  mid-way. A list of `table1` objects produces one page (or more, with
  pagination) per table.

- file:

  Path to the output PDF file. Must be a single character string ending
  in `".pdf"`. Not required when `preview` is not `FALSE`.

- pg_width:

  Page width in inches.

- pg_height:

  Page height in inches.

- page_num:

  A [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
  specification for automatic page numbering, where `{i}` is the current
  page number and `{n}` is the total number of pages. Set to `NULL` to
  disable.

- preview:

  Controls preview rendering instead of PDF output:

  - `FALSE` (default): write to `file` as normal.

  - `TRUE`: render all pages to the current graphics device.

  - An integer vector: render only the specified page numbers (e.g.
    `preview = c(1, 3)` renders pages 1 and 3).

  In preview mode each page is drawn via
  [`grid::grid.newpage()`](https://rdrr.io/r/grid/grid.newpage.html) (so
  knitr captures it as an inline graphic). Returns `NULL` invisibly.

- ...:

  Arguments passed on to
  [`export_tfl_page`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)

  `padding`

  :   Vertical space between adjacent present sections, as a `unit`
      object. Separator rules (if enabled) are drawn at the midpoint of
      this gap and do not consume additional space.

  `header_left,header_center,header_right`

  :   Header text. Accepts `NULL`, a single string, or a character
      vector (collapsed with `"\\n"`). Horizontal justification follows
      the argument name (left/center/right). Vertically top-justified.
      Overridden by `x$header_left` etc.

  `caption`

  :   Caption text below the header and above the content. Accepts
      `NULL`, a single string, or a character vector. Full-width;
      justification controlled by `caption_just`. Overridden by
      `x$caption`.

  `footnote`

  :   Footnote text below the content. Accepts `NULL`, a single string,
      or a character vector. Full-width; justification controlled by
      `footnote_just`. Overridden by `x$footnote`.

  `footer_left,footer_center,footer_right`

  :   Footer text. Mirror of header arguments. Vertically
      bottom-justified. Overridden by `x$footer_left` etc.

  `gp`

  :   Typography specification. Accepts either a single
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

  `header_rule`

  :   Separator rule drawn between the header and the next section
      (caption or content), fitted within the `padding` gap. Accepts:

      - `FALSE`: no rule

      - `TRUE`: full-width rule

      - A numeric in `(0, 1]`: rule spanning that fraction of viewport
        width, centered

      - A grob (typically a `linesGrob`): drawn as-is, centered
        vertically in the padding gap.

  `footer_rule`

  :   Separator rule between the last body section (footnote or content)
      and the footer. Same specification as `header_rule`.

  `caption_just`

  :   Horizontal justification for the caption.

  `footnote_just`

  :   Horizontal justification for the footnote.

  `content_just`

  :   Horizontal justification for character string content. One of
      `"left"` (default), `"right"`, or `"centre"`. Ignored when
      `x$content` is a ggplot or grob.

  `margins`

  :   Outer page margins as a `unit` vector with elements `t`, `r`, `b`,
      `l` (top, right, bottom, left).

  `min_content_height`

  :   Minimum acceptable content area height as a `unit` object. An
      error is raised if the computed content height falls below this
      value.

  `overflow_action`

  :   One of `"error"` (default) or `"warn"`. Controls how
      width-overflow conditions are reported when the content does not
      fit in its allocated area:

      - `"error"`: append the message to the layout-error vector and
        abort before drawing (no PDF page is produced).

      - `"warn"`: emit
        [`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html)
        and continue rendering. The PDF is produced with the overflow
        visibly clipped by `grid`, which is useful for diagnosing what
        is too wide. See issue \#30.

      The same setting applies to all width-overflow detections: the
      page-level content grob check (any `grob` content wider than the
      content viewport), the
      [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
      total-width check (when `allow_col_split = FALSE` and the column
      total still exceeds the page after wrapping), and the
      [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
      per-column check (any single column — or any data column combined
      with the row-header group columns — wider than the page).

## Value

- Normal mode (`preview = FALSE`): the normalized absolute path to the
  PDF file, returned invisibly.

- Preview mode: `NULL`, invisibly.

## Details

Arguments forwarded via `...` serve as defaults for all pages and are
overridden by per-page list elements in `x`.

## See also

[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
for single-page layout control.

## Examples

``` r
if (FALSE) { # \dontrun{
library(ggplot2)

# Single plot
p <- ggplot(mtcars, aes(wt, mpg)) + geom_point()
export_tfl(p, "single.pdf")

# Multiple plots with per-page captions
plots <- list(
  list(content = p, caption = "Weight vs MPG"),
  list(content = ggplot(mtcars, aes(hp, mpg)) + geom_point(),
       caption = "Horsepower vs MPG")
)
export_tfl(plots, "report.pdf",
  header_left  = "My Report",
  header_right = format(Sys.Date())
)

# Preview the first two pages without writing a file
export_tfl(plots, preview = c(1, 2),
  header_left = "My Report"
)
} # }
```
