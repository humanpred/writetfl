# CLAUDE.md — writetfl package

This file captures the complete design context for the `writetfl` R
package, derived from an extended design conversation. Read this before
writing any code. Companion documents are in `design/`:

- `design/DESIGN.md` — rationale for every decision
- `design/ARCHITECTURE.md` — function hierarchy, data flow, internal
  contracts
- `design/DECISIONS.md` — decision log with alternatives considered
- `design/TESTING.md` — test plan and scope

Note: `docs/` is reserved for pkgdown site output and is git-ignored.

**Keep `design/` up to date.** Whenever a code change affects any of the
following, update the relevant file(s) in the same commit or PR:

- Function signatures, names, or return values → `ARCHITECTURE.md`
- New files, renamed files, or removed files → `ARCHITECTURE.md`
- Data contracts between internal helpers → `ARCHITECTURE.md`
- Why a design choice was made, or a choice is reversed → `DESIGN.md`
- Any new decision, or an existing decision that changes →
  `DECISIONS.md` (add a new D-N entry; do not delete old entries — note
  the change inline)
- New test files, new test areas, or changes to testing conventions →
  `TESTING.md`

------------------------------------------------------------------------

## What this package does

`writetfl` provides exported functions for writing ggplot objects, grid
grobs, and paginated data-frame tables to multi-page PDF files with
precise, composable page layout:

- [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
  — opens a PDF device, loops over a list of pages, closes device
- [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
  — lays out a single page with header, caption, content, footnote, and
  footer sections using `grid` viewports
- [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)
  — creates a paginated table configuration from a data frame
- [`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md)
  — specifies per-column display properties for
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md)

The core design goal is **pixel-precise control** of whitespace on a PDF
page, specifically supporting clinical/regulatory report aesthetics
where outer margins, annotation zones, and content areas must be
independently sized and never overlap.

------------------------------------------------------------------------

## Package metadata

| Field     | Value                                                                                                      |
|-----------|------------------------------------------------------------------------------------------------------------|
| Package   | `writetfl`                                                                                                 |
| Type      | R package (roxygen2, testthat)                                                                             |
| License   | AGPL-3                                                                                                     |
| R deps    | `dplyr`, `ggplot2`, `grid`, `glue`, `rlang`                                                                |
| Suggests  | `flextable`, `formatters`, `gt`, `rtables`, `testthat (>= 3.0.0)`, `withr`, `knitr`, `rmarkdown`, `tibble` |
| Namespace | All helpers unexported except `export_tfl`, `export_tfl_page`, `tfl_table`, `tfl_colspec`                  |

------------------------------------------------------------------------

## Exported function signatures

``` r
export_tfl(
  x,
  file      = NULL,
  pg_width  = 11,
  pg_height = 8.5,
  page_num  = "Page {i} of {n}",
  preview   = FALSE,
  ...
)

export_tfl_page(
  x,
  padding            = unit(0.5, "lines"),
  header_left        = NULL,
  header_center      = NULL,
  header_right       = NULL,
  caption            = NULL,
  footnote           = NULL,
  footer_left        = NULL,
  footer_center      = NULL,
  footer_right       = NULL,
  gp                 = gpar(),
  header_rule        = FALSE,
  footer_rule        = FALSE,
  caption_just       = "left",
  footnote_just      = "left",
  margins            = unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
  min_content_height = unit(3, "inches"),
  page_i             = NULL,
  preview            = FALSE,
  ...
)
```

`...` in
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
absorbs: - `overlap_warn_mm` (default `2`) — near-miss threshold in mm;
`NULL` disables overlap detection

`...` in
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
is forwarded to
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md).

------------------------------------------------------------------------

## Key behavioral rules (implement exactly as specified)

### Input coercion — `export_tfl()`

- If `x` is a single ggplot object or grob, wrap it as
  `list(list(content = x))`
- If `x` is a `tfl_table` object, convert via
  [`tfl_table_to_pagelist()`](https://humanpred.github.io/writetfl/reference/tfl_table_to_pagelist.md)
- If `x` is a list, each element must itself be a list with at least
  `$content`
- `file` must be a single character string ending in `".pdf"`; error
  otherwise (not required when `preview` is not `FALSE`)

### Page argument merging — `export_tfl()` → `export_tfl_page()`

For each page `i`, arguments are merged in this **precedence order**
(first wins):

1.  `x[[i]]` named list elements (highest priority)
2.  Direct arguments passed via `...` from
    [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
3.  [`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
    defaults (lowest priority)

`page_num` is processed with `glue::glue("Page {i} of {n}")` where `i`
is the current page index and `n` is `length(x)`. The result is placed
into `footer_right` **only if `footer_right` is absent after step 1 and
2 merging**. In other words, `footer_right` always beats `page_num`.

### Section presence and padding

The five vertical sections in top-to-bottom order:

    header  (header_left + header_center + header_right)
    caption
    content                         ← fills all remaining space
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
[`gpar()`](https://rdrr.io/r/grid/gpar.html) object 4.
[`gpar()`](https://rdrr.io/r/grid/gpar.html) default

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

| Input                        | Behavior                                           |
|------------------------------|----------------------------------------------------|
| `FALSE`                      | No rule drawn                                      |
| `TRUE`                       | Full-width rule (equivalent to `1.0`)              |
| numeric in `(0, 1]`          | Centered rule at that fraction of viewport width   |
| grob (typically `linesGrob`) | Used as-is, centered vertically in the padding gap |

Rule is drawn at the **vertical midpoint of the padding gap** between
sections. It does not consume additional vertical space.

### `draw_content()` dispatch

``` r
draw_content <- function(content, vp) {
  if (inherits(content, "ggplot")) {
    pushViewport(vp)
    print(content, newpage = FALSE)
    popViewport()
  } else if (inherits(content, "grob")) {
    pushViewport(vp)
    grid.draw(content)
    popViewport()
  } else {
    rlang::abort("x$content must be a ggplot object or a grid grob")
  }
}
```

### Device lifecycle

``` r
export_tfl <- function(...) {
  # validate first, before opening device
  pdf(file, width = pg_width, height = pg_height)
  on.exit(dev.off(), add = TRUE)
  # loop
}
```

`on.exit(dev.off(), add = TRUE)` ensures the device closes even if a
page errors.

### Return value

- Normal mode: `invisible(normalizePath(file, mustWork = FALSE))`
- Preview mode: `invisible(NULL)`

### `preview` mode

`export_tfl(..., preview = TRUE)`: - Calls `grid.newpage()` and draws to
the currently open device - Does NOT open or close any device -
`preview = c(1, 3)` renders only the specified pages - Returns
`invisible(NULL)` (no grob capture, to avoid double-render bugs)

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
            └── content_vp
                  Inset from outer_vp by the space consumed by
                  header + header_padding + caption + caption_padding (top)
                  and footnote_padding + footnote + footer_padding + footer (bottom).
                  The ggplot is printed or grob drawn here.

All `grid.text()` / `grid.draw()` coordinates are relative to the
**currently active viewport**. Be precise about which viewport is active
at each draw call.

------------------------------------------------------------------------

## File structure

    writetfl/
    ├── CLAUDE.md                         ← this file
    ├── DESCRIPTION
    ├── NAMESPACE                         ← generated by roxygen2
    ├── R/
    │   ├── export_tfl.R                  ← exported; S3 generic + methods, .export_tfl_pages()
    │   ├── export_tfl_page.R             ← exported; single-page layout and draw
    │   ├── ggtibble.R                    ← export_tfl.ggtibble(), ggtibble_to_pagelist()
    │   ├── tfl_table.R                   ← exported; tfl_table(), tfl_colspec()
    │   ├── normalize.R                   ← normalize_text(), normalize_rule()
    │   ├── grob_builders.R               ← build_section_grobs(), build_text_grob()
    │   ├── measure.R                     ← measure_grob_height(), measure_section_heights(),
    │   │                                    measure_header_widths(), measure_footer_widths()
    │   ├── resolve_gp.R                  ← resolve_gp(), merge_gpar()
    │   ├── overlap.R                     ← check_overlap()
    │   ├── layout.R                      ← compute_content_height(), check_content_height()
    │   ├── draw.R                        ← draw_content(), draw_header_section(),
    │   │                                    draw_caption_section(), draw_footnote_section(),
    │   │                                    draw_footer_section(), draw_rule()
    │   ├── utils.R                       ← validate_file_arg(), coerce_x_to_pagelist(),
    │   │                                    build_page_args()
    │   ├── gt.R                          ← export_tfl.gt_tbl(), gt_to_pagelist(),
    │   │                                    .extract_gt_annotations(), .clean_gt()
    │   ├── rtables.R                     ← export_tfl.VTableTree(),
    │   │                                    rtables_to_pagelist(),
    │   │                                    .extract_rtables_annotations(),
    │   │                                    .clean_rtables(), .rtables_to_grob()
    │   ├── flextable.R                   ← export_tfl.flextable(),
    │   │                                    flextable_to_pagelist(),
    │   │                                    .extract_flextable_annotations(),
    │   │                                    .clean_flextable(),
    │   │                                    .flextable_to_grob(),
    │   │                                    .paginate_flextable()
    │   ├── reexports.R                   ← re-exports unit, gpar from grid
    │   ├── table_columns.R               ← resolve_col_specs(), compute_col_widths(),
    │   │                                    paginate_cols()
    │   ├── table_rows.R                  ← measure_row_heights_tbl(), paginate_rows()
    │   ├── table_draw.R                  ← build_table_grob(),
    │   │                                    drawDetails.tfl_table_grob()
    │   ├── table_pagelist.R              ← tfl_table_to_pagelist(),
    │   │                                    compute_table_content_area()
    │   └── table_utils.R                 ← .make_outer_vp(), measurement/formatting
    │                                        helpers shared across table_* files
    ├── tests/
    │   ├── testthat.R
    │   └── testthat/
    │       ├── test-normalize.R
    │       ├── test-resolve_gp.R
    │       ├── test-overlap.R
    │       ├── test-layout.R
    │       ├── test-measure.R
    │       ├── test-validate.R
    │       ├── test-table_utils.R
    │       ├── test-table_draw.R
    │       ├── test-tfl_table.R
    │       ├── test-ggtibble.R
    │       ├── test-gt.R
    │       ├── test-rtables.R
    │       ├── test-flextable.R
    │       └── test-integration.R
    ├── vignettes/
    │   ├── writetfl.Rmd
    │   ├── v01-figure_output.Rmd
    │   ├── v02-tfl_table_intro.Rmd
    │   ├── v03-tfl_table_styling.Rmd
    │   ├── v04-troubleshooting.Rmd
    │   ├── v05-gt_tables.Rmd
    │   ├── v06-rtables.Rmd
    │   └── v07-flextable.Rmd
    └── design/
        ├── DESIGN.md
        ├── ARCHITECTURE.md
        ├── DECISIONS.md
        └── TESTING.md
