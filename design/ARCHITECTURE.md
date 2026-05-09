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
  │  dispatches via UseMethod("export_tfl")
  │
  ├── export_tfl.default()                             — export_tfl.R
  │     ├── .validate_export_args(page_num, preview, file)
  │     ├── coerce_x_to_pagelist(x)                    — utils.R
  │     │     accepts: ggplot | grob | list-of-page-specs
  │     │     wraps single ggplot/grob as list(list(content = x))
  │     └── .export_tfl_pages(...)                     — export_tfl.R (shared)
  │
  ├── export_tfl.tfl_table()                           — export_tfl.R
  │     ├── .validate_export_args(...)
  │     ├── tfl_table_to_pagelist(...)                  — table_pagelist.R
  │     └── .export_tfl_pages(...)
  │
  ├── export_tfl.ggtibble()                            — ggtibble.R
  │     ├── .validate_export_args(...)
  │     ├── ggtibble_to_pagelist(x, sub_tfl, sub_tfl_sep,  — ggtibble.R
  │     │                       sub_tfl_collapse, sub_tfl_prefix)
  │     │     per row, appends "label: value; ..." suffix to caption via
  │     │     .apply_sub_tfl_caption() (sub_tfl.R); raw column names used
  │     │     as labels (no colspec system for ggtibble)
  │     └── .export_tfl_pages(...)
  │
  ├── export_tfl.gt_tbl()                              — gt.R
  │     ├── rlang::check_installed("gt")
  │     ├── .validate_export_args(...)
  │     ├── gt_to_pagelist(x)                           — gt.R
  │     └── .export_tfl_pages(...)
  │
  ├── export_tfl.list()                                — export_tfl.R
  │     ├── .validate_export_args(...)
  │     ├── [all gt_tbl?] → gt_to_pagelist() per element
  │     ├── [otherwise]   → coerce_x_to_pagelist(x)
  │     └── .export_tfl_pages(...)
  │
  └── .export_tfl_pages(pages, file, ...)              — export_tfl.R (shared)
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
  ├── if grob content and not (ggplot/character/tfl_table_grob): — layout.R
  │     check_content_width(grobWidth, vp_width, overflow_action, errors)
  │     [tfl_table_grob is skipped: compute_col_widths() already ran a
  │      more precise per-column check during tfl_table_to_pagelist()]
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
        ├── [if tbl$sub_tfl is non-NULL — sub-table branch]
        │     .compute_sub_tfl_groups(data, sub_tfl)    — sub_tfl.R
        │       ordered list of sub-groups; factor levels for factors,
        │       first-appearance order otherwise
        │     for each sub-group g:
        │       .strip_sub_tfl_cols(sub_tbl)            — sub_tfl.R
        │         drops sub_tfl from data, group_vars, cols, col_widths,
        │         col_labels, col_align, wrap_cols
        │       .format_sub_tfl_caption(tbl, g$values)  — sub_tfl.R
        │         label: value joined by sep, multi-col joined by collapse
        │         labels resolved via .resolve_col_label() (colspec → flat → name)
        │       .apply_sub_tfl_caption(base, suffix, prefix) — sub_tfl.R
        │         base + prefix + suffix; suffix alone when base is NULL
        │       tfl_table_to_pagelist(sub_tbl, ...)     [recursion, sub_tfl=NULL]
        │       attach $caption to each returned page spec
        │     concatenate per-group pages → return
        │
        ├── compute_table_content_area(...)             — table_pagelist.R
        │     scratch device + outer_vp to measure annotation heights
        ├── resolve_col_specs(tbl)                      — table_columns.R
        ├── compute_col_widths(resolved_cols, ...)      — table_columns.R
        │     └── .apply_col_wrapping(...)
        │         paginate_cols(...)
        ├── [scratch device + outer_vp] measure heights:
        │     .measure_header_row_height()              — table_utils.R
        │     measure_row_heights_tbl() → cell_h_mat    — table_rows.R
        │       Per-cell height matrix [nrow × ncol]; each entry includes
        │       the v_pad_in (top + bottom padding).  This is the input to
        │       the per-page row-height resolver below.
        │     .measure_cont_row_height()                — table_utils.R
        ├── paginate_rows(...)                          — table_rows.R
        │   Span-aware pagination: per-page tentative recompute via
        │   .compute_page_row_heights() to drive page-fit decisions.  Each
        │   committed page spec carries $row_heights_in (orphan-correct).
        └── for rp × cg:
              build_table_grob(row_page, col_group_idx,  — table_draw.R
                               n_group_cols, resolved_cols, tbl,
                               cell_heights_in_mat, cont_row_h_in,
                               is_first_col_page, is_last_col_page)
                → gTree of class "tfl_table_grob"

  [grob passed as x$content to export_tfl_page()]

drawDetails.tfl_table_grob(x, recording)               — table_draw.R
  ├── Reuse or recompute: header_row_h, cont_row_h, suppress_mat
  ├── row_h_vec ← row_page$row_heights_in (committed by pagination), or
  │   recompute via .compute_page_row_heights(cell_heights_in_mat, …).
  ├── span_end_mat (per group column, per row) — last row index in the
  │   span starting at each non-suppressed row; lets non-suppressed group
  │   cells be drawn with a clip viewport spanning the full span height
  │   so multi-line labels flow into suppressed rows below (rowspan-style).
  ├── Draw column header row     (.draw_header_row)
  ├── Draw col_header_rule       (grid.lines)
  ├── Draw top continuation row  (.draw_cont_row)
  ├── for each data row:
  │     group rule before row    (grid.lines)
  │     draw each cell           (.draw_cell_text); for non-suppressed
  │       group cells whose span > 1 row, pass span_h instead of row_h
  │       so the clip viewport extends over the whole span.
  │     row rule after row       (grid.lines), suppressed when row ri+1
  │       has any suppressed group column (rule would slice a label).
  ├── group_rule_after_last      (grid.lines)
  ├── Draw bottom continuation row (.draw_cont_row)
  ├── Draw row_header_sep        (grid.lines)
  └── Draw col_cont_msg side labels (grid.grid.text, rotated)
        right side (rot = -90°) when !is_last_col_page
        left side  (rot = +90°) when !is_first_col_page
```

---

## Function hierarchy — gt path

```
export_tfl(x = gt_tbl_obj, ...)                      [exported]
  └── gt_to_pagelist(gt_obj, pg_width, pg_height,      — gt.R
                      dots, page_num)
        ├── .extract_gt_annotations(gt_obj)            — gt.R
        │     extracts title+subtitle → caption
        │     extracts source_notes + footnotes → footnote
        ├── .clean_gt(gt_obj)                           — gt.R
        │     gt::rm_header() |> gt::rm_source_notes() |> gt::rm_footnotes()
        ├── gt::as_gtable(cleaned) → full grob
        ├── .gt_content_height(...)                     — gt.R
        │     reuses compute_table_content_area()
        ├── .gt_grob_height(grob, ...)                  — gt.R
        │     measures grob height in scratch device
        │
        ├── [fits on one page] → single page spec
        │
        └── [overflows] → .paginate_gt(cleaned, ...)    — gt.R
              ├── .gt_row_groups(cleaned)               — gt.R
              │     extracts group boundaries from _stub_df
              └── greedy assignment:
                    for each group:
                      .rebuild_gt_subset(cleaned, rows) — gt.R
                        re-indexes: _formats, _styles,
                                    _substitutions, _transforms
                        copies:     _boxhead, _options, _spanners,
                                    _stubhead, _locale, _summary_cols
                        filters:    _summary (by present groups)
                      gt::as_gtable(sub_gt)
                      .gt_grob_height(sub_grob, ...)
                    → list of row index vectors per page

export_tfl(x = list_of_gt_tbl, ...)                   [exported]
  └── export_tfl.list()
        ├── detects all elements are gt_tbl
        ├── lapply(x, gt_to_pagelist, ...) |> unlist(recursive = FALSE)
        └── .export_tfl_pages(...)

export_tfl(x = VTableTree_obj, ...)                  [exported]
  └── export_tfl.VTableTree()                          — rtables.R
        └── rtables_to_pagelist(x, ...)                — rtables.R
              ├── .extract_rtables_annotations(x)      — rtables.R
              │     main_title+subtitles → caption
              │     main_footer+prov_footer → footnote
              ├── .clean_rtables(x)                    — rtables.R
              │     clears title, subtitles, footers
              ├── .rtables_content_height(...)          — rtables.R
              │     reuses compute_table_content_area()
              ├── .rtables_content_width(...)           — rtables.R
              ├── .rtables_lpp_cpp(...)                 — rtables.R
              │     converts inches → lpp/cpp via font metrics
              ├── rtables::paginate_table(cleaned, lpp, cpp)
              │     returns list of VTableTree sub-tables
              └── for each sub-table:
                    .rtables_to_grob(page, font_*)     — rtables.R
                      formatters::toString(page) → textGrob(...)
                    → page spec with $content, $caption, $footnote

export_tfl(x = list_of_VTableTree, ...)              [exported]
  └── export_tfl.list()
        ├── detects all elements are VTableTree
        ├── lapply(x, rtables_to_pagelist, ...) |> unlist(recursive = FALSE)
        └── .export_tfl_pages(...)

export_tfl(x = flextable_obj, ...)                  [exported]
  └── export_tfl.flextable()                          — flextable.R
        └── flextable_to_pagelist(x, ...)              — flextable.R
              ├── .extract_flextable_annotations(x)    — flextable.R
              │     caption from ft$caption$value
              │     footnote from footer row chunks
              ├── .clean_flextable(x)                  — flextable.R
              │     deletes footer rows
              ├── .flextable_content_height(...)        — flextable.R
              │     reuses compute_table_content_area()
              ├── .flextable_content_width(...)         — flextable.R
              ├── .flextable_to_grob(cleaned, w)       — flextable.R
              │     .flextable_set_pdf_font(ft)
              │     flextable::gen_grob(ft, fit="width")
              ├── .flextable_grob_height(grob)         — flextable.R
              │     sum(grob$ftpar$heights)
              ├── if too tall:
              │     .paginate_flextable(cleaned, h, w)  — flextable.R
              │       greedy row-based pagination
              │       .rebuild_flextable_subset(ft, rows)
              │       → list of sub-flextable objects
              └── for each page:
                    .flextable_to_grob(page, w)
                    → page spec with $content, $caption, $footnote

export_tfl(x = list_of_flextable, ...)              [exported]
  └── export_tfl.list()
        ├── detects all elements are flextable
        ├── lapply(x, flextable_to_pagelist, ...) |> unlist(recursive = FALSE)
        └── .export_tfl_pages(...)

export_tfl(x = table1_obj, ...)                    [exported]
  └── export_tfl.table1()                            — table1.R
        └── table1_to_pagelist(x, ...)                — table1.R
              ├── .extract_table1_annotations(x)      — table1.R
              │     attr(x, "obj")$caption → caption
              │     attr(x, "obj")$footnote → footnote
              ├── .table1_variable_groups(x)           — table1.R
              │     identifies row boundaries per variable from obj$contents
              ├── table1::t1flex(x)                    → flextable
              ├── .clean_flextable(ft)                 — flextable.R (reused)
              ├── .flextable_content_height(...)        — flextable.R (reused)
              ├── .flextable_content_width(...)         — flextable.R (reused)
              ├── .flextable_to_grob(ft, w)            — flextable.R (reused)
              ├── .flextable_grob_height(grob)         — flextable.R (reused)
              ├── if too tall:
              │     .paginate_table1(ft, groups, h, w)  — table1.R
              │       group-aware greedy pagination
              │       .paginate_oversized_group(ft, rows, h, w)
              │       .rebuild_flextable_subset(ft, rows) — flextable.R (reused)
              └── for each page:
                    .flextable_to_grob(page, w)
                    → page spec with $content, $caption, $footnote

export_tfl(x = list_of_table1, ...)                [exported]
  └── export_tfl.list()
        ├── detects all elements are table1
        ├── lapply(x, table1_to_pagelist, ...) |> unlist(recursive = FALSE)
        └── .export_tfl_pages(...)
```

---

## File inventory

| File | Contents |
|------|----------|
| `R/export_tfl.R` | `export_tfl()` S3 generic — `.default`, `.tfl_table`, `.list` methods; `.validate_export_args()`, `.export_tfl_pages()` shared helpers |
| `R/ggtibble.R` | `export_tfl.ggtibble()`, `ggtibble_to_pagelist()` — ggtibble connector (soft dep) |
| `R/export_tfl_page.R` | `export_tfl_page()` — single-page layout and draw |
| `R/draw.R` | `draw_content()`, `draw_header_section()`, `draw_footer_section()`, `draw_caption_section()`, `draw_footnote_section()`, `draw_rule()` |
| `R/grob_builders.R` | `build_section_grobs()`, `build_text_grob()` |
| `R/measure.R` | `measure_grob_width()`, `measure_grob_height()`, `measure_section_heights()`, `measure_header_widths()`, `measure_footer_widths()` |
| `R/normalize.R` | `normalize_text()`, `wrap_normalized_text()`, `normalize_rule()` |
| `R/resolve_gp.R` | `resolve_gp()`, `merge_gpar()` |
| `R/overlap.R` | `check_overlap()` |
| `R/layout.R` | `compute_figure_height()`, `check_figure_height()`, `check_content_width()`, `.overflow_signal()` |
| `R/utils.R` | `validate_file_arg()`, `coerce_x_to_pagelist()`, `build_page_args()` |
| `R/gt.R` | `export_tfl.gt_tbl()`, `gt_to_pagelist()`, `.extract_gt_annotations()`, `.clean_gt()`, `.gt_content_height()`, `.gt_grob_height()`, `.gt_row_groups()`, `.paginate_gt()`, `.rebuild_gt_subset()` |
| `R/rtables.R` | `export_tfl.VTableTree()`, `rtables_to_pagelist()`, `.extract_rtables_annotations()`, `.clean_rtables()`, `.rtables_content_height()`, `.rtables_content_width()`, `.rtables_lpp_cpp()`, `.rtables_to_grob()` |
| `R/flextable.R` | `export_tfl.flextable()`, `flextable_to_pagelist()`, `.extract_flextable_annotations()`, `.clean_flextable()`, `.flextable_content_height()`, `.flextable_content_width()`, `.flextable_grob_height()`, `.flextable_to_grob()`, `.flextable_set_pdf_font()`, `.paginate_flextable()`, `.rebuild_flextable_subset()` |
| `R/table1.R` | `export_tfl.table1()`, `table1_to_pagelist()`, `.extract_table1_annotations()`, `.table1_variable_groups()`, `.paginate_table1()`, `.paginate_oversized_group()` |
| `R/reexports.R` | `%||%` from rlang |
| `R/tfl_table.R` | `tfl_colspec()`, `tfl_table()`, `print.tfl_table()`, `.check_named_subset()` |
| `R/table_columns.R` | `resolve_col_specs()`, `compute_col_widths()`, `.apply_col_wrapping()`, `paginate_cols()` |
| `R/table_rows.R` | `measure_row_heights_tbl()` (returns per-cell matrix), `.compute_page_row_heights()`, `paginate_rows()` |
| `R/table_draw.R` | `build_table_grob()`, `drawDetails.tfl_table_grob()`, `.compute_cell_suppression()`, `.draw_header_row()`, `.draw_cont_row()`, `.draw_cell_text()` |
| `R/table_pagelist.R` | `tfl_table_to_pagelist()`, `compute_table_content_area()` |
| `R/sub_tfl.R` | `.compute_sub_tfl_groups()`, `.format_sub_tfl_caption()`, `.apply_sub_tfl_caption()`, `.strip_sub_tfl_cols()`, `.resolve_col_label()` |
| `R/table_utils.R` | `.make_outer_vp()`, `.width_in()`, `.height_in()`, `.measure_header_row_height()`, `.measure_cont_row_height()`, `.gp_with_lineheight()`, `.compute_group_starts()`, `.compute_group_sizes()`, `.compute_group_rule_info()` (used when `simplify_rowspan = TRUE` for outer-level rule visibility and partial-width start column), `.collect_col_strings()`, `.fmt_cell()`, `.fmt_cell_vec()`, `.measure_max_string_width()`, `.resolve_table_gp()`, `.resolve_table_cell_gp()`, `.default_align()`, `.wrap_text()` |

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

compute_col_widths(resolved_cols, data, content_width_in, tbl, ...,
                   overflow_action = c("error", "warn"))
  1. Measure auto-size columns: max string width over unique values
     (limited to max_measure_rows rows for efficiency)
  2. Apply min_col_width floor to auto-sized columns
  3. Allocate relative-weight columns proportionally from remaining width
  4. If total > content_width_in and wrap_eligible cols exist:
       .apply_col_wrapping() narrows wrap cols iteratively
  5. Per-column / group-aware overflow check (issue #30):
       For group cols j:  widths_in[j] > content_width_in  → signal
       For data cols  j:  grp_w + widths_in[j] > content_width_in → signal
       (signal = abort under "error", rlang::warn() under "warn")
  6. Total-width check, only when allow_col_split = FALSE:
       total_w > content_width_in → signal
  7. paginate_cols() splits into column groups (always called; under "warn"
       it gracefully paginates around the overflow)
  8. Each resolved col gets $width_in set (inches, scalar)

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
  → numeric MATRIX [nrow(data) × length(resolved_cols)] of heights in inches
  Each entry includes the v_pad_in (top + bottom padding) so that
  per-row max(matrix[i, ]) is the row height when no spanning happens.
  Uses memoised string-height to avoid re-measuring repeated values.
  max_measure_rows: sample the longest rows to cap measurement cost.
  Non-sampled rows take the per-column max-of-sampled value.

.compute_page_row_heights(cell_h_mat, page_rows, resolved_cols,
                          group_vars, suppress_mat)
  → numeric vector of length(page_rows)
  Span-aware per-page resolver.  Initialises row_h[ri] = max over
  non-group columns of cell_h_mat[page_rows[ri], col].  Then for each
  group column from innermost (last) to outermost (first), finds spans
  in suppress_mat and grows row_h[ri_start] by any deficit between the
  label height (cell_h_mat[page_rows[ri_start], col_g]) and the sum of
  the span's row heights.  Innermost-first ensures outer groups can
  borrow the space inner groups already pushed for.  Early-exit when
  no group columns or suppress_mat = NULL — returns per-row max over
  *all* columns (no flow when suppression is disabled).

paginate_rows(data, cell_h_mat, resolved_cols, group_vars,
              cont_row_h, header_row_h, content_height_in,
              row_cont_msg, group_rule, suppress_repeated_groups)
  → list of row_page structs:
    { rows, is_cont_top, is_cont_bottom, group_starts, row_heights_in }
  Span-aware pagination via per-page tentative recompute: each candidate
  row addition recomputes suppress_mat and .compute_page_row_heights for
  c(cur_rows, i) and checks the total against content_height_in.  When
  overflow is detected, the previously committed (cur_rows, committed_rh)
  pair is flushed — committed_rh captures the orphan-correct heights for
  the row that landed alone at the page boundary.
```

---

## Sub-tables — `sub_tfl` data contracts

### `.compute_sub_tfl_groups(data, sub_tfl)` → `list`

```
data:    data.frame
sub_tfl: character vector of column names in data

Output:  ordered list of group specs, each:
  list(
    values  = named list (one entry per sub_tfl col, scalar value),
    row_idx = integer vector (1-based rows of data in this group)
  )
```

Ordering: factor columns contribute their levels (in level order); character /
numeric columns contribute first-appearance order. The Cartesian-style
ordering iterates by `sub_tfl` left-to-right (outer to inner).

### `.resolve_col_label(tbl, col_name)` → `character(1)`

```
Priority (highest first):
  tbl$cols[[k]]$label   where tbl$cols[[k]]$col == col_name
  tbl$col_labels[col_name]   if named and non-NA
  col_name              fallback
```

Shared between `resolve_col_specs()` and `.format_sub_tfl_caption()`.

### `.format_sub_tfl_caption(tbl, values)` → `character(1)`

```
values: named list (names = sub_tfl columns, values = scalars for one group)

For each entry:
  label  <- .resolve_col_label(tbl, name)
  pair   <- paste(label, format(value), sep = tbl$sub_tfl_sep)
Result   <- paste(pairs, collapse = tbl$sub_tfl_collapse)
```

### `.apply_sub_tfl_caption(base, suffix, prefix)` → `character(1)`

```
base   = NULL → return suffix
base   ≠ NULL → return paste0(base, prefix, suffix)
```

### `.strip_sub_tfl_cols(tbl)` → `tfl_table`

Removes `tbl$sub_tfl` entries from `tbl$cols` (list of `tfl_colspec`),
`tbl$col_widths`, `tbl$col_labels`, `tbl$col_align`, `tbl$wrap_cols` (when
named). Caller is responsible for filtering `tbl$data` and updating
`tbl$group_vars`.

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
