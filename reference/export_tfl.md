# Export a list of TFLs to a multi-page PDF

Opens a PDF device, renders each page using
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md),
and closes the device. Guarantees device closure via
[`on.exit()`](https://rdrr.io/r/base/on.exit.html) even if an error
occurs during rendering.

## Usage

``` r
export_tfl(
  x,
  file,
  pg_width = 11,
  pg_height = 8.5,
  page_num = "Page {i} of {n}",
  ...
)
```

## Arguments

- x:

  A single `ggplot` object, a grid grob (e.g. from `gt::as_gtable()` or
  `gridExtra::tableGrob()`), or a named list of page specifications.
  Each page specification is a list with a required `content` element (a
  `ggplot` or grob) and optional elements corresponding to the text
  arguments of
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md):
  `header_left`, `header_center`, `header_right`, `caption`, `footnote`,
  `footer_left`, `footer_center`, `footer_right`. Per-page list elements
  take precedence over values supplied via `...`.

- file:

  Path to the output PDF file. Must be a single character string ending
  in `".pdf"`.

- pg_width:

  Page width in inches.

- pg_height:

  Page height in inches.

- page_num:

  A [`glue::glue()`](https://glue.tidyverse.org/reference/glue.html)
  specification for automatic page numbering, where `{i}` is the current
  page number and `{n}` is the total number of pages. Set to `NULL` to
  disable.

- ...:

  Additional arguments passed to
  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).
  These serve as defaults for all pages and are overridden by per-page
  list elements in `x`.

## Value

The normalized absolute path to the PDF file, returned invisibly.

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
} # }
```
