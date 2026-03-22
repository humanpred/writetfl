# writetfl

**Standardized table, figure, and listing output for clinical trial
reporting.**

`writetfl` produces multi-page PDF files from `ggplot2` figures with the
precise, composable page layouts required for clinical trial TFL
deliverables and regulatory submissions. Each page is divided into up to
five vertical sections — header, caption, figure, footnote, and footer —
whose heights are computed dynamically from live font metrics so that
the figure always fills exactly the remaining space. Nothing ever
overlaps.

The package is designed for clinical, regulatory, and technical
reporting contexts where outer margins, annotation zones, and figure
areas must be independently sized and reproducible across many pages. It
is equally suitable for any setting that demands consistent,
pixel-precise page layout.

------------------------------------------------------------------------

## Installation

``` r
# Install from GitHub (requires remotes or pak)
remotes::install_github("yourorg/writetfl")
```

------------------------------------------------------------------------

## Quick start

``` r
library(writetfl)
library(ggplot2)

p <- ggplot(mtcars, aes(wt, mpg)) +
  geom_point() +
  labs(x = "Weight (1000 lb)", y = "Miles per gallon")

# Single figure — "Page 1 of 1" added automatically
export_fig_as_pdf(p, file = "figure.pdf")
```

A multi-page report with a shared header and per-page captions:

``` r
pages <- list(
  list(
    figure  = ggplot(mtcars, aes(wt, mpg)) + geom_point(),
    caption = "Figure 1. Weight is negatively associated with fuel efficiency.",
    footnote = "n = 32 vehicles."
  ),
  list(
    figure  = ggplot(mtcars, aes(hp, mpg)) + geom_point(),
    caption = "Figure 2. Higher horsepower predicts lower fuel efficiency.",
    footnote = "Pearson r = -0.78."
  )
)

export_fig_as_pdf(
  pages,
  file         = "report.pdf",
  header_left  = "Fuel Economy Analysis",
  header_right = format(Sys.Date(), "%d %b %Y"),
  header_rule  = TRUE,
  footer_rule  = TRUE
)
```

------------------------------------------------------------------------

## Page layout

    ┌─────────────────────────────────────────────────┐  ← page edge
    │              (outer margin)                     │
    │  ┌───────────────────────────────────────────┐  │
    │  │  header_left  header_center  header_right │  │  header
    │  │ ─────────────────────────────────────────── │  │  ← header_rule (optional)
    │  │  caption                                  │  │  caption
    │  │                                           │  │
    │  │           figure (fills remainder)        │  │  figure
    │  │                                           │  │
    │  │  footnote                                 │  │  footnote
    │  │ ─────────────────────────────────────────── │  │  ← footer_rule (optional)
    │  │  footer_left  footer_center  footer_right │  │  footer
    │  └───────────────────────────────────────────┘  │
    │              (outer margin)                     │
    └─────────────────────────────────────────────────┘

Absent sections and their padding gaps are suppressed entirely — no
blank space is reserved for them.

------------------------------------------------------------------------

## Key features

### Shared vs per-page arguments

Arguments passed via `...` to
[`export_fig_as_pdf()`](https://humanpred.github.io/writetfl/reference/export_fig_as_pdf.md)
apply to every page. An element in a page’s list always wins over the
shared default.

``` r
export_fig_as_pdf(
  pages,
  file        = "report.pdf",
  header_left = "Shared title",     # applies to all pages ...
  # page list can override:  list(figure = p, header_left = "Override")
)
```

Priority order (highest first): page list element → `...` argument →
function default.

### Automatic page numbering

`page_num` (default `"Page {i} of {n}"`) populates `footer_right` unless
a `footer_right` value is already set. Use a
[glue](https://glue.tidyverse.org/) template or set to `NULL` to
disable.

``` r
export_fig_as_pdf(plots, file = "report.pdf", page_num = "{i} / {n}")
export_fig_as_pdf(plots, file = "report.pdf", page_num = NULL)
```

### Separator rules

`header_rule` and `footer_rule` draw a line inside the padding gap
between sections. They accept `FALSE` (off), `TRUE` (full-width), a
numeric fraction of viewport width, or a custom `linesGrob`.

``` r
export_fig_as_pdf(p, file = "ruled.pdf",
  header_left = "Title",
  header_rule = TRUE,
  footer_rule = 0.5          # half-width, centred
)
```

### Typography

Pass a single [`gpar()`](https://rdrr.io/r/grid/gpar.html) to style all
annotation text, or a named list for section- or element-level control.
Resolution priority: element \> section \> global.

``` r
export_fig_as_pdf(
  p,
  file        = "styled.pdf",
  header_left = "Protocol XY-001",
  caption     = "Figure 1. Results.",
  gp = list(
    header       = grid::gpar(fontsize = 11, fontface = "bold"),
    header_right = grid::gpar(fontsize =  9, col = "gray50"),
    caption      = grid::gpar(fontsize =  9, fontface = "italic"),
    footer       = grid::gpar(fontsize =  8)
  )
)
```

### Multi-line text

Any text argument accepts a character vector (joined with `"\n"`) or a
string with embedded newlines. Section height adjusts automatically.

``` r
export_fig_as_pdf(p, file = "multiline.pdf",
  caption = c(
    "Figure 1. Fuel efficiency declines with vehicle weight.",
    "Data: Motor Trend (1974). Points represent individual models."
  )
)
```

### Layout safety checks

Before any drawing occurs, `writetfl` validates the layout and reports
all problems at once:

- **Overlap detection** — if left and right header or footer text
  collide, the call errors. Near-misses within `overlap_warn_mm`
  millimetres (default 2) trigger a warning; set
  `overlap_warn_mm = NULL` to disable.
- **Minimum figure height** — if the figure would be squeezed below
  `min_figheight` (default `unit(3, "inches")`), the call errors with
  the computed and minimum heights.

### Preview mode

`export_figpage_to_pdf(..., preview = TRUE)` draws to the currently open
device without opening or closing a PDF. Use this in RStudio or Positron
to iterate on layout interactively before writing the final file.

``` r
library(grid)
export_figpage_to_pdf(
  x           = list(figure = p),
  header_left = "Draft",
  caption     = "Figure 1.",
  header_rule = TRUE,
  preview     = TRUE
)
```

------------------------------------------------------------------------

## Function reference

| Function                          | Description                                                          |
|-----------------------------------|----------------------------------------------------------------------|
| `export_fig_as_pdf(x, file, ...)` | Open a PDF device, render one page per element of `x`, close device. |
| `export_figpage_to_pdf(x, ...)`   | Render a single page to the current device.                          |

### `export_fig_as_pdf()` arguments

| Argument    | Default             | Description                                                                                                                |
|-------------|---------------------|----------------------------------------------------------------------------------------------------------------------------|
| `x`         | —                   | A `ggplot` object, or a list of page specs (each with `$figure`).                                                          |
| `file`      | —                   | Output path; must end in `".pdf"`.                                                                                         |
| `pg_width`  | `11`                | Page width in inches.                                                                                                      |
| `pg_height` | `8.5`               | Page height in inches.                                                                                                     |
| `page_num`  | `"Page {i} of {n}"` | Glue template for auto page numbering; `NULL` disables.                                                                    |
| `...`       |                     | Passed to [`export_figpage_to_pdf()`](https://humanpred.github.io/writetfl/reference/export_figpage_to_pdf.md); see below. |

### `export_figpage_to_pdf()` arguments

| Argument                   | Default                                      | Description                                                                  |
|----------------------------|----------------------------------------------|------------------------------------------------------------------------------|
| `x`                        | —                                            | List with `$figure` (ggplot) and optional text elements.                     |
| `header_left/center/right` | `NULL`                                       | Header text; `NULL` suppresses the slot.                                     |
| `caption`                  | `NULL`                                       | Caption text (below header, above figure).                                   |
| `footnote`                 | `NULL`                                       | Footnote text (below figure).                                                |
| `footer_left/center/right` | `NULL`                                       | Footer text.                                                                 |
| `gp`                       | [`gpar()`](https://rdrr.io/r/grid/gpar.html) | Typography: bare [`gpar()`](https://rdrr.io/r/grid/gpar.html) or named list. |
| `header_rule`              | `FALSE`                                      | Rule between header and next section.                                        |
| `footer_rule`              | `FALSE`                                      | Rule between last body section and footer.                                   |
| `caption_just`             | `"left"`                                     | Caption justification.                                                       |
| `footnote_just`            | `"left"`                                     | Footnote justification.                                                      |
| `margins`                  | `unit(rep(0.5,4), "inches")`                 | Named `unit` vector `c(t, r, b, l)`.                                         |
| `padding`                  | `unit(0.5, "lines")`                         | Gap between adjacent sections.                                               |
| `min_figheight`            | `unit(3, "inches")`                          | Error if figure shorter than this.                                           |
| `overlap_warn_mm`          | `2`                                          | Near-miss warning threshold in mm; `NULL` disables.                          |
| `preview`                  | `FALSE`                                      | Draw to current device without opening/closing PDF.                          |

------------------------------------------------------------------------

## Dependencies

| Package   | Role                                     |
|-----------|------------------------------------------|
| `ggplot2` | Figure rendering                         |
| `grid`    | Viewport arithmetic, grobs, font metrics |
| `glue`    | Page number template interpolation       |
| `rlang`   | Structured errors and warnings           |

------------------------------------------------------------------------

## License

AGPL-3 — see the [GNU Affero General Public License
v3](https://www.gnu.org/licenses/agpl-3.0.html) for details.
