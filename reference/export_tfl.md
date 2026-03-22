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

  A single `ggplot` object, a grid grob (e.g. from `gt::as_gtable()` or
  `gridExtra::tableGrob()`), a
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  object, a `ggtibble` object (from the ggtibble package), or a named
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

  Additional arguments passed to
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).
  These serve as defaults for all pages and are overridden by per-page
  list elements in `x`.

## Value

- Normal mode (`preview = FALSE`): the normalized absolute path to the
  PDF file, returned invisibly.

- Preview mode: `NULL`, invisibly.

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
