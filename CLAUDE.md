# CLAUDE.md — writetfl package

This file captures the complete design context for the `writetfl` R
package, derived from an extended design conversation. Read this before
writing any code. Companion documents are in `docs/`:

- `docs/DESIGN.md` — rationale for every decision
- `docs/ARCHITECTURE.md` — function hierarchy, data flow, internal
  contracts
- `docs/DECISIONS.md` — decision log with alternatives considered
- `docs/TESTING.md` — test plan and scope

------------------------------------------------------------------------

## What this package does

`writetfl` provides two exported functions for writing ggplot objects to
multi-page PDF files with precise, composable page layout:

- [`export_fig_as_pdf()`](https://humanpred.github.io/writetfl/reference/export_fig_as_pdf.md)
  — opens a PDF device, loops over a list of pages, closes device
- [`export_figpage_to_pdf()`](https://humanpred.github.io/writetfl/reference/export_figpage_to_pdf.md)
  — lays out a single page with header, caption, figure, footnote, and
  footer sections using `grid` viewports

The core design goal is **pixel-precise control** of whitespace on a PDF
page, specifically supporting clinical/regulatory report aesthetics
where outer margins, annotation zones, and figure areas must be
independently sized and never overlap.

------------------------------------------------------------------------

## Package metadata

| Field     | Value                                                                      |
|-----------|----------------------------------------------------------------------------|
| Package   | `writetfl`                                                                 |
| Type      | R package (roxygen2, testthat)                                             |
| License   | TBD by author                                                              |
| R deps    | `ggplot2`, `grid`, `glue`, `rlang`                                         |
| Suggests  | `testthat (>= 3.0.0)`                                                      |
| Namespace | All helpers unexported except `export_fig_as_pdf`, `export_figpage_to_pdf` |

------------------------------------------------------------------------

## Exported function signatures

``` r
export_fig_as_pdf(
  x,
  file,
  pg_width  = 11,
  pg_height = 8.5,
  margins   = unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  page_num  = "Page {i} of {n}",
  ...
)

export_figpage_to_pdf(
  x,
  padding        = unit(0.2, "lines"),
  header_left    = NULL,
  header_center  = NULL,
  header_right   = NULL,
  caption        = NULL,
  footnote       = NULL,
  footer_left    = NULL,
  footer_center  = NULL,
  footer_right   = NULL,
  gp             = gpar(),
  header_rule    = FALSE,
  footer_rule    = FALSE,
  caption_just   = "left",
  footnote_just  = "left",
  min_figheight  = unit(3, "inches"),
  preview        = FALSE,
  ...
)
```

`...` in
[`export_figpage_to_pdf()`](https://humanpred.github.io/writetfl/reference/export_figpage_to_pdf.md)
absorbs: - `overlap_warn_mm` (default `2`) — near-miss threshold in mm;
`NULL` disables overlap detection

`...` in
[`export_fig_as_pdf()`](https://humanpred.github.io/writetfl/reference/export_fig_as_pdf.md)
is forwarded to
[`export_figpage_to_pdf()`](https://humanpred.github.io/writetfl/reference/export_figpage_to_pdf.md).

------------------------------------------------------------------------

## Key behavioral rules (implement exactly as specified)

### Input coercion — `export_fig_as_pdf()`

- If `x` is a single ggplot object, wrap it as `list(list(figure = x))`
- If `x` is a list, each element must itself be a list with at least
  `$figure`
- `file` must be a single character string ending in `".pdf"`; error
  otherwise

### Page argument merging — `export_fig_as_pdf()` → `export_figpage_to_pdf()`

For each page `i`, arguments are merged in this **precedence order**
(first wins):

1.  `x[[i]]` named list elements (highest priority)
2.  Direct arguments passed via `...` from
    [`export_fig_as_pdf()`](https://humanpred.github.io/writetfl/reference/export_fig_as_pdf.md)
3.  [`export_figpage_to_pdf()`](https://humanpred.github.io/writetfl/reference/export_figpage_to_pdf.md)
    defaults (lowest priority)

`page_num` is processed with `glue::glue("Page {i} of {n}")` where `i`
is the current page index and `n` is `length(x)`. The result is placed
into `footer_right` **only if `footer_right` is absent after step 1 and
2 merging**. In other words, `footer_right` always beats `page_num`.

### Section presence and padding

The five vertical sections in top-to-bottom order:

    header  (header_left + header_center + header_right)
    caption
    figure                          ← fills all remaining space
    footnote
    footer  (footer_left + footer_center + footer_right)

- A section is **present** if any of its elements is non-NULL
- Padding (`padding` argument) is inserted between **any two vertically
  adjacent present sections**
- If a section is absent, no space and no padding is reserved for it
- Rules (if enabled) are drawn **inside the padding gap** between
  header↔︎caption and footnote↔︎footer respectively; they do not add
  height

### Text normalization — `normalize_text(x)`

Accepts: `NULL`, single string, character vector. Returns:
`list(text = <single string>, nlines = <integer>)`

- Character vector → collapsed with `"\n"`
- Embedded `"\n"` → counted for `nlines`
- `NULL` → `list(text = NULL, nlines = 0L)`

### Height measurement — `measure_grob_height(grob, nlines)`

1.  Primary:
    `convertHeight(grobHeight(grob), "inches", valueOnly = TRUE)`
2.  Fallback cross-check:
    `nlines * convertHeight(stringHeight("M"), "inches", valueOnly = TRUE)`
3.  Return `max(primary, fallback)` as a conservative estimate
4.  **Must be called while the target viewport is active**

### `gp` resolution — `resolve_gp(gp, section, element)`

Priority (highest to lowest): 1. `gp[[element]]` e.g. `gp$header_left`
2. `gp[[section]]` e.g. `gp$header` 3. `gp` itself if it is a bare
`gpar()` object 4. `gpar()` default

Merge by building from lowest to highest, overwriting field-by-field. A
helper `merge_gpar(base, override)` handles field-level merging.

### Horizontal overlap detection — `check_overlap()`

For each of header and footer rows, check: -
`left_width + center_width/2 > 0.5 * vp_width` → left encroaches on
center - `right_width + center_width/2 > 0.5 * vp_width` → right
encroaches on center - `left_width + right_width > vp_width` → left and
right overlap (no center)

Threshold behavior (controlled by `overlap_warn_mm`): - True overlap
(gap \< 0) → collect into error vector - Near-miss (gap ≥ 0 but \<
`overlap_warn_mm` mm) →
[`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html) -
`overlap_warn_mm = NULL` → skip overlap detection entirely

### Error collection

Throughout layout computation, errors are appended to a character
vector. **No drawing occurs until all layout checks pass.** At the end
of layout planning, if errors exist:

``` r
rlang::abort(paste(errors, collapse = "\n"))
```

Warnings are issued immediately via
[`rlang::warn()`](https://rlang.r-lib.org/reference/abort.html) as they
are detected.

### `header_rule` / `footer_rule` normalization — `normalize_rule(x)`

| Input               | Behavior                                           |
|---------------------|----------------------------------------------------|
| `FALSE`             | No rule drawn                                      |
| `TRUE`              | Full-width rule (equivalent to `1.0`)              |
| numeric in `(0, 1]` | Centered rule at that fraction of viewport width   |
| `linesGrob`         | Used as-is, centered vertically in the padding gap |

Rule is drawn at the **vertical midpoint of the padding gap** between
sections. It does not consume additional vertical space.

### `draw_figure()` dispatch

``` r
draw_figure <- function(fig, vp) {
  if (inherits(fig, "ggplot")) {
    pushViewport(vp)
    print(fig, newpage = FALSE)
    popViewport()
  } else {
    # FUTURE: add grob, recordedPlot dispatch here
    rlang::abort("x$figure must be a ggplot object (other types not yet supported)")
  }
}
```

### Device lifecycle

``` r
export_fig_as_pdf <- function(...) {
  # validate first, before opening device
  pdf(file, width = pg_width, height = pg_height)
  on.exit(dev.off(), add = TRUE)
  # loop
}
```

`on.exit(dev.off(), add = TRUE)` ensures the device closes even if a
page errors.

### Return value

Both exported functions return
`invisible(normalizePath(file, mustWork = FALSE))`.

### `preview` mode

`export_figpage_to_pdf(..., preview = TRUE)`: - Calls `grid.newpage()`
and draws to the currently open device - Does NOT open or close any
device - Useful for interactive layout tuning in RStudio / Positron
viewer

------------------------------------------------------------------------

## Viewport architecture

Every page uses a two-level viewport stack pushed inside `outer_vp`:

    PDF page (root viewport, full page)
      └── outer_vp
            Inset by margins (t/r/b/l) from page edges.
            This is the "hard" margin — nothing ever draws outside it.
            Coordinates: npc (0,0) = bottom-left of content area.
            │
            ├── [annotations drawn here while outer_vp is active]
            │   header section grobs
            │   footer section grobs
            │   rule grobs (in padding gaps)
            │
            └── figure_vp
                  Inset from outer_vp by the space consumed by
                  header + header_padding + caption + caption_padding (top)
                  and footnote_padding + footnote + footer_padding + footer (bottom).
                  The ggplot is printed here with newpage = FALSE.

All `grid.text()` / `grid.draw()` coordinates are relative to the
**currently active viewport**. Be precise about which viewport is active
at each draw call.

------------------------------------------------------------------------

## File structure to create

    writetfl/
    ├── CLAUDE.md                         ← this file
    ├── DESCRIPTION
    ├── NAMESPACE                         ← generated by roxygen2
    ├── R/
    │   ├── export_fig_as_pdf.R           ← exported; roxygen2 docs
    │   ├── export_figpage_to_pdf.R       ← exported; roxygen2 docs
    │   ├── normalize.R                   ← normalize_text(), normalize_rule()
    │   ├── grob_builders.R               ← build_section_grobs(), build_text_grob()
    │   ├── measure.R                     ← measure_grob_height(), measure_section_heights(),
    │   │                                    measure_header_widths(), measure_footer_widths()
    │   ├── resolve_gp.R                  ← resolve_gp(), merge_gpar()
    │   ├── overlap.R                     ← check_overlap()
    │   ├── layout.R                      ← compute_figure_height(), check_figure_height()
    │   ├── draw.R                        ← draw_figure(), draw_header_section(),
    │   │                                    draw_caption_section(), draw_footnote_section(),
    │   │                                    draw_footer_section(), draw_rule()
    │   └── utils.R                       ← validate_file_arg(), coerce_x_to_pagelist(),
    │                                        build_page_args(), collect_errors()
    ├── tests/
    │   ├── testthat.R
    │   └── testthat/
    │       ├── test-normalize.R
    │       ├── test-resolve_gp.R
    │       ├── test-overlap.R
    │       ├── test-layout.R
    │       ├── test-validate.R
    │       └── test-integration.R
    └── docs/
        ├── DESIGN.md
        ├── ARCHITECTURE.md
        ├── DECISIONS.md
        └── TESTING.md

------------------------------------------------------------------------

## Implementation order

Implement in this order to allow incremental testing:

1.  `utils.R` — validation and coercion (no grid dependencies, fully
    unit-testable)
2.  `normalize.R` — text and rule normalization (no grid dependencies)
3.  `resolve_gp.R` — gp merging (no grid dependencies)
4.  `grob_builders.R` — depends on grid, normalize, resolve_gp
5.  `measure.R` — depends on grid, grob_builders
6.  `overlap.R` — depends on measure
7.  `layout.R` — depends on measure
8.  `draw.R` — depends on all of the above
9.  `export_figpage_to_pdf.R` — assembles all helpers
10. `export_fig_as_pdf.R` — wraps export_figpage_to_pdf
11. Tests — written alongside each file above
12. Roxygen docs — written as functions are implemented
