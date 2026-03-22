# Architecture — writetfl

This document describes the internal structure of the package: function hierarchy,
data contracts between helpers, the viewport coordinate model, and the table
pagination pipeline.

---

## Exported API

| Function | Purpose |
|----------|---------|
| `export_tfl(x, file, ...)` | Write one or more pages to a multi-page PDF, or render to the current device in preview mode |
| `export_tfl_page(x, ...)` | Lay out and render a single page |
| `tfl_table(x, ...)` | Create a paginated table configuration object |
| `tfl_colspec(col, ...)` | Specify per-column display properties |

---

## Function hierarchy — figure/grob path

```
export_tfl(x, file, preview, ...)                     [exported, S3 generic]
  │
  ├── export_tfl.default()                             — ggplot / grob / list
  │     ├── .validate_export_args()                    — export_tfl.R
  │     ├── coerce_x_to_pagelist(x)                    — utils.R
  │     │     accepts: ggplot | grob | list-of-page-specs
  │     │     wraps single ggplot/grob as list(list(content = x))
  │     └── .export_tfl_pages(...)                     — export_tfl.R (shared)
  │
  ├── export_tfl.tfl_table()                           — tfl_table objects
  │     ├── .validate_export_args()
  │     ├── tfl_table_to_pagelist(...)                  — table_pagelist.R
  │     └── .export_tfl_pages(...)
  │
  └── export_tfl.ggtibble()                            — ggtibble objects
        ├── .validate_export_args()                    — ggtibble.R
        ├── ggtibble_to_pagelist(x)                    — ggtibble.R
        └── .export_tfl_pages(...)

.export_tfl_pages(pages, file, ...)                    [internal helper]
  └── [preview = FALSE] PDF loop:
  │     grDevices::pdf(file, ...)
  │     on.exit(dev.off(), add = TRUE)
  │     for i in seq_along(pages):
  │       build_page_args(pages[[i]], dots, page_num, i, n)  — utils.R
  │       export_tfl_page(x = pages[[i]], ...)               [exported]
  │     invisible(normalizePath(file))
  │
  └── [preview = TRUE or integer] Preview loop:
        for j in seq_along(page_idx):
          build_page_args(pages[[i]], dots, page_num, i, n)
          export_tfl_page(x = pages[[i]], ..., preview = TRUE)
        invisible(NULL)

export_tfl_page(x, ...)                               [exported]
  ├── normalize_all_inputs()
  │     ├── normalize_text(header_left / center / right)  — normalize.R
  │     ├── normalize_text(caption / footnote)
  │     ├── normalize_text(footer_left / center / right)
  │     └── normalize_rule(header_rule / footer_rule)     — normalize.R
  ├── resolve_all_gp()
  │     └── resolve_gp(gp, section, element) [× 8]       — resolve_gp.R
  │           └── merge_gpar(base, override)
  ├── build_section_grobs()                               — grob_builders.R
  │     └── build_text_grob(norm, gp, x_npc, just)
  ├── grid.newpage()
  ├── .make_outer_vp(margins)                             — table_utils.R
  ├── pushViewport(outer_vp)
  │
  ├── [MEASUREMENT PHASE — outer_vp active]
  ├── measure_section_heights()                           — measure.R
  │     └── measure_grob_height(grob, nlines) [× 5]
  ├── measure_header_widths()                             — measure.R
  ├── measure_footer_widths()                             — measure.R
  │
  ├── [VALIDATION PHASE — collect errors, no drawing]
  ├── check_overlap(widths, vp_width, overlap_warn_mm)    — overlap.R
  ├── compute_figure_height(...)                          — layout.R
  ├── check_figure_height(h, min_content_height, errors)  — layout.R
  ├── if errors: rlang::abort(paste(errors, collapse="\n"))
  │
  ├── [DRAWING PHASE]
  ├── draw_header_section(grobs, vp_width)                — draw.R
  ├── draw_rule(header_rule, y_mid, vp_width)             — draw.R
  ├── draw_caption_section(grob, y_top)                   — draw.R
  ├── draw_content(x$content, content_vp)                 — draw.R
  │     ├── ggplot branch: pushViewport; print(p, newpage=FALSE); popViewport
  │     └── grob branch:   pushViewport; grid.draw(grob); popViewport
  ├── draw_footnote_section(grob, y_bottom)               — draw.R
  ├── draw_rule(footer_rule, y_mid, vp_width)             — draw.R
  ├── draw_footer_section(grobs, vp_width)                — draw.R
  └── popViewport()  [outer_vp]
```

---

## Function hierarchy — tfl_table path

```
export_tfl(x = tfl_table_obj, ...)                    [exported]
  └── tfl_table_to_pagelist(tbl, pg_width, pg_height,  — table_pagelist.R
                             dots, page_num)
        ├── compute_table_content_area(...)             — table_pagelist.R
        │     scratch device + outer_vp to measure annotation heights
        ├── resolve_col_specs(tbl)                      — table_columns.R
        ├── compute_col_widths(resolved_cols, ...)      — table_columns.R
        │     └── .apply_col_wrapping(...)
        │         paginate_cols(...)
        ├── [scratch device + outer_vp] measure heights:
        │     .measure_header_row_height()              — table_utils.R
        │     measure_row_heights_tbl()                 — table_rows.R
        │     .measure_cont_row_height()                — table_utils.R
        ├── paginate_rows(...)                          — table_rows.R
        └── for rp × cg:
              build_table_grob(row_page, col_group_idx,  — table_draw.R
                               n_group_cols, resolved_cols, tbl,
                               row_heights_in, cont_row_h_in,
                               is_first_col_page, is_last_col_page)
                → gTree of class "tfl_table_grob"

  [grob passed as x$content to export_tfl_page()]

drawDetails.tfl_table_grob(x, recording)               — table_draw.R
  ├── Reuse or recompute: header_row_h, cont_row_h, row_h_vec
  ├── Draw column header row     (.draw_header_row)
  ├── Draw col_header_rule       (grid.lines)
  ├── Draw top continuation row  (.draw_cont_row)
  ├── for each data row:
  │     group rule before row    (grid.lines)
  │     draw each cell           (.draw_cell_text)
  │     row rule after row       (grid.lines, if row_rule && not last)
  ├── group_rule_after_last      (grid.lines)
  ├── Draw bottom continuation row (.draw_cont_row)
  ├── Draw row_header_sep        (grid.lines)
  └── Draw col_cont_msg side labels (grid.grid.text, rotated)
        right side (rot = -90°) when !is_last_col_page
        left side  (rot = +90°) when !is_first_col_page
```

---

## File inventory

| File | Contents |
|------|----------|
| `R/export_tfl.R` | `export_tfl()` S3 generic + `.default`, `.tfl_table` methods, `.validate_export_args()`, `.export_tfl_pages()` |
| `R/ggtibble.R` | `export_tfl.ggtibble()`, `ggtibble_to_pagelist()` — ggtibble connector (soft dep) |
| `R/export_tfl_page.R` | `export_tfl_page()` — single-page layout and draw |
| `R/draw.R` | `draw_content()`, `draw_header_section()`, `draw_footer_section()`, `draw_caption_section()`, `draw_footnote_section()`, `draw_rule()` |
| `R/grob_builders.R` | `build_section_grobs()`, `build_text_grob()` |
| `R/measure.R` | `measure_grob_width()`, `measure_grob_height()`, `measure_section_heights()`, `measure_header_widths()`, `measure_footer_widths()` |
| `R/normalize.R` | `normalize_text()`, `normalize_rule()` |
| `R/resolve_gp.R` | `resolve_gp()`, `merge_gpar()` |
| `R/overlap.R` | `check_overlap()` |
| `R/layout.R` | `compute_figure_height()`, `check_figure_height()` |
| `R/utils.R` | `validate_file_arg()`, `coerce_x_to_pagelist()`, `build_page_args()` |
| `R/reexports.R` | `%||%` from rlang |
| `R/tfl_table.R` | `tfl_colspec()`, `tfl_table()`, `print.tfl_table()`, `.check_named_subset()` |
| `R/table_columns.R` | `resolve_col_specs()`, `compute_col_widths()`, `.apply_col_wrapping()`, `paginate_cols()` |
| `R/table_rows.R` | `measure_row_heights_tbl()`, `paginate_rows()` |
| `R/table_draw.R` | `build_table_grob()`, `drawDetails.tfl_table_grob()`, `.draw_header_row()`, `.draw_cont_row()`, `.draw_cell_text()` |
| `R/table_pagelist.R` | `tfl_table_to_pagelist()`, `compute_table_content_area()` |
| `R/table_utils.R` | `.make_outer_vp()`, `.width_in()`, `.height_in()`, `.measure_header_row_height()`, `.measure_cont_row_height()`, `.gp_with_lineheight()`, `.compute_group_starts()`, `.compute_group_sizes()`, `.collect_col_strings()`, `.fmt_cell()`, `.fmt_cell_vec()`, `.measure_max_string_width()`, `.resolve_table_gp()`, `.resolve_table_cell_gp()`, `.default_align()`, `.wrap_text()` |

---

## Data contracts

### `normalize_text(x)` → `list`

```
Input:  NULL | character(1) | character(n)
Output: list(
  text   = character(1) | NULL,   # \n-collapsed string
  nlines = integer(1)             # 0 if NULL
)
```

### `normalize_rule(x)` → `FALSE | grob`

```
Input:  FALSE | TRUE | numeric (0,1] | grob (typically linesGrob)
Output: FALSE        (no rule)
      | grob         (ready to draw, centered in padding gap)
```

When input is `TRUE`, output spans full width (`x = unit(c(0,1), "npc")`).
When input is numeric `w`, output spans `((1-w)/2, (1+w)/2)` in npc.

### `resolve_gp(gp, section, element)` → `gpar()`

```
gp:       gpar() | list(...)
section:  one of "header" | "caption" | "content" | "footnote" | "footer"
element:  one of "header_left" | "header_center" | "header_right" |
                 "caption" | "footnote" |
                 "footer_left" | "footer_center" | "footer_right"

Priority (highest first):
  gp[[element]]   e.g. gp$header_left
  gp[[section]]   e.g. gp$header
  gp itself       if inherits(gp, "gpar")
  gpar()          fallback
```

### `merge_gpar(base, override)` → `gpar()`

```r
merge_gpar <- function(base, override) {
  merged <- c(as.list(base), as.list(override))
  merged <- merged[!duplicated(names(merged), fromLast = TRUE)]
  do.call(gpar, merged)
}
```

### `measure_grob_height(grob, nlines)` → `numeric` (inches)

**Must be called while the target viewport is active.**

```r
primary  <- convertHeight(grobHeight(grob), "inches", valueOnly = TRUE)
fallback <- nlines * convertHeight(stringHeight("M"), "inches", valueOnly = TRUE)
max(primary, fallback)
```

Returns `0` for `NULL` grob.

### `compute_figure_height(...)` → numeric (inches)

```
content_h = vp_height
          - header_h - caption_h - footnote_h - footer_h
          - n_padding_gaps * padding_in
```

Rules do NOT subtract from this — they live within the padding gap.

### `check_overlap(widths, vp_width_in, overlap_warn_mm)`

```
widths: list(left, center, right)  # in inches, per row (header or footer)
```

Checks for both header and footer rows:
1. `left + center/2 > 0.5 * vp_width` → left encroaches on center
2. `right + center/2 > 0.5 * vp_width` → right encroaches on center
3. `left + right > vp_width` (no center) → left/right overlap

Gap < 0 → error string; gap in `[0, overlap_warn_mm/25.4)` → `rlang::warn()`.
`overlap_warn_mm = NULL` skips all checks.

### `coerce_x_to_pagelist(x)` → `list`

```
Input:  ggplot | grob → list(list(content = x))
        list of page specs → validated and returned as-is

Each page spec must have:
  $content  — ggplot or grob (required)
  $header_left / header_center / header_right  (optional)
  $caption / $footnote                         (optional)
  $footer_left / footer_center / footer_right  (optional)
```

### `build_page_args(page_list, dots, page_num, i, n)` → `list`

```
Precedence: page_list > dots > page_num fills footer_right only if absent
```

```r
args <- modifyList(dots, page_list)   # page_list wins
if (is.null(args$footer_right) && !is.null(pn_text)) {
  args$footer_right <- pn_text
}
```

---

## Viewport coordinate model

```
┌─────────────────────────────────────────────────┐  ← PDF page
│              (outer margin)                     │
│   ┌─────────────────────────────────────────┐   │
│   │              outer_vp                    │   │
│   │  Inset by margins (t/r/b/l) from page.  │   │
│   │  npc (0,0) = bottom-left of content.     │   │
│   │                                          │   │
│   │  header section   [grid.text while here] │   │
│   │  · · · padding gap (rule at midpoint) ·  │   │
│   │  caption section  [grid.text while here] │   │
│   │  · · · padding gap · · · · · · · · · ·   │   │
│   │  ┌──────────────────────────────────┐    │   │
│   │  │          content_vp              │    │   │
│   │  │  ggplot: print(p, newpage=FALSE) │    │   │
│   │  │  grob:   grid.draw(grob)         │    │   │
│   │  └──────────────────────────────────┘    │   │
│   │  · · · padding gap · · · · · · · · · ·   │   │
│   │  footnote section [grid.text while here] │   │
│   │  · · · padding gap (rule at midpoint) ·  │   │
│   │  footer section   [grid.text while here] │   │
│   └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Y-coordinate accounting (top-down, inches from top of outer_vp)

```
y_cursor = vp_height

if header present:   draw at y_cursor (top-just); y_cursor -= header_h
if header + next:    [rule at y_cursor - padding/2]; y_cursor -= padding
if caption present:  draw at y_cursor (top-just); y_cursor -= caption_h
if caption + next:   y_cursor -= padding

content_vp: top = y_cursor, height = content_h
y_cursor = content_vp bottom

if content + next:   y_cursor -= padding
if footnote:         draw at y_cursor (bottom-just); y_cursor -= footnote_h
if footnote + footer:[rule at y_cursor - padding/2]; y_cursor -= padding
if footer:           draw at y_cursor (bottom-just)
```

All y values converted to npc by dividing by `vp_height`.

---

## tfl_table grob — coordinate model

The `tfl_table_grob` gTree is rendered via `drawDetails.tfl_table_grob()` inside the `content_vp` assigned to it by `export_tfl_page()`.

```
content_vp (from export_tfl_page)
  │  x_offset = max(0, (vp_w - sum(col_widths)) / 2)  [centre-aligns table]
  │
  │  y_cursor = 0 (distance from TOP, increases downward)
  │
  ├── header row fill    (grid.rect, if gp$header_row$fill)
  ├── column header row  (if show_col_names)
  ├── col_header_rule    (grid.lines, if col_header_rule = TRUE)
  ├── top continuation row  (if is_cont_top)
  ├── for each data row:
  │     group rule          (grid.lines, if group_rule & starts new group)
  │     data row fill       (grid.rect, if gp$data_row$fill; cycled by fill_by)
  │     cell text           (.draw_cell_text in clipping viewport)
  │     row rule            (grid.lines, if row_rule && not last row)
  ├── group_rule_after_last (grid.lines, if group_rule_after_last)
  ├── bottom continuation row (if is_cont_bottom)
  ├── row_header_sep      (vertical grid.lines after last group col)
  └── col_cont_msg labels (rotated grid.text, if col split):
        right of table  rot = -90°  when !is_last_col_page
        left of table   rot = +90°  when !is_first_col_page
```

Column x-positions (in inches from left edge of `content_vp`):
```r
col_x_left  <- c(0, cumsum(col_widths_in[-n_disp_cols])) + x_offset
col_x_right <- cumsum(col_widths_in)                      + x_offset
```

---

## Section presence logic

```r
header_present  <- any(!is.null(header_left), !is.null(header_center),
                       !is.null(header_right))
caption_present <- !is.null(caption)
content_present <- TRUE   # always required
footnote_present<- !is.null(footnote)
footer_present  <- any(!is.null(footer_left),  !is.null(footer_center),
                       !is.null(footer_right))

present        <- c(header_present, caption_present, content_present,
                    footnote_present, footer_present)
n_padding_gaps <- sum(present[-length(present)] & present[-1L])
```

---

## Text grob placement within header/footer rows

| Element | `x` (npc) | `just` |
|---------|-----------|--------|
| left    | `0`       | `c("left",   "top")` header / `c("left",   "bottom")` footer |
| center  | `0.5`     | `c("center", "top")` header / `c("center", "bottom")` footer |
| right   | `1`       | `c("right",  "top")` header / `c("right",  "bottom")` footer |

Caption and footnote: full-width, justification controlled by `caption_just`
/ `footnote_just`.

---

## tfl_table — column width pipeline

```
resolve_col_specs(tbl)
  → list of per-column specs (one per column in source order):
    { col, label, width (unit/numeric/NULL), align, wrap,
      gp, is_group_col }

compute_col_widths(resolved_cols, data, content_width_in, tbl, ...)
  1. Measure auto-size columns: max string width over unique values
     (limited to max_measure_rows rows for efficiency)
  2. Apply min_col_width floor to auto-sized columns
  3. Allocate relative-weight columns proportionally from remaining width
  4. If total > content_width_in and wrap_eligible cols exist:
       .apply_col_wrapping() narrows wrap cols iteratively
  5. If total still > content_width_in and allow_col_split:
       paginate_cols() splits into column groups
  6. Each resolved col gets $width_in set (inches, scalar)

paginate_cols(col_indices, col_widths_in, group_col_indices,
              content_width_in, balance_col_pages)
  → list of integer vectors; each vector is a set of column indices
    for one column page (group cols prepended to every page)
    If balance_col_pages = TRUE: redistribute data cols evenly
```

---

## tfl_table — row pagination pipeline

```
measure_row_heights_tbl(data, resolved_cols, gp_tbl, cell_padding,
                         na_string, line_height, max_measure_rows)
  → numeric vector of length nrow(data), heights in inches
  Uses memoised string-height to avoid re-measuring repeated values.
  max_measure_rows: sample the longest rows to cap measurement cost.

paginate_rows(data, row_heights, cont_row_h, header_row_h,
              avail_h, group_vars, row_cont_msg, group_rule)
  → list of row_page structs:
    { rows, is_cont_top, is_cont_bottom, group_starts }
  Group-aware: tries to keep group blocks together; places
  continuation-marker rows at page boundaries.
```

---

## Error messages (current, for test regexp matching)

| Condition | Pattern |
|-----------|---------|
| Bad file extension | `"file must be a single character string ending in '.pdf'"` |
| No content in page list | `"x\\[\\[<i>\\]\\] must contain a 'content' element"` |
| `x$content` not ggplot/grob | `"x\\$content must be a ggplot object or a grid grob"` |
| Content height too short | `"Content height .* is less than min_content_height"` |
| Header left/center overlap | `"header_left and header_center overlap"` |
| Header right/center overlap | `"header_right and header_center overlap"` |
| Header left/right overlap | `"header_left and header_right overlap"` |
| Footer variants | Same patterns with `"footer_"` prefix |
| Group cols not first | `"Group columns must be the first columns"` |
| Column overflow (no split) | `"Total column width .* exceeds"` |
| preview out of range | `"out of range"` |
