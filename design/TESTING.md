# Test Plan — writetfl

All tests use `testthat` (>= 3.0.0) with `testthat::test_that()`.
Visual regression tests are explicitly out of scope (see D-18 in DECISIONS.md).
**Coverage target: 100% line coverage** (see D-25).

---

## Test organisation

One test file per source file — `tests/testthat/test-<name>.R` covers
`R/<name>.R`. See D-26 in DECISIONS.md.

| Test file | Covers |
|-----------|--------|
| `test-normalize.R` | `normalize_text()`, `normalize_rule()` |
| `test-resolve_gp.R` | `resolve_gp()`, `merge_gpar()` |
| `test-overlap.R` | `check_overlap()` |
| `test-layout.R` | `compute_content_height()`, `check_content_height()` |
| `test-validate.R` | `validate_file_arg()`, `coerce_x_to_pagelist()` |
| `test-measure.R` | `measure_grob_width()` |
| `test-draw.R` | `draw_content()`, `draw_rule()`, `draw_header_section()`, `draw_footer_section()`, `draw_caption_section()`, `draw_footnote_section()` |
| `test-grob_builders.R` | `build_text_grob()`, `build_section_grobs()` |
| `test-export_tfl.R` | `export_tfl()` — file validation, return values, preview mode, device lifecycle, tfl_table coercion, argument merging |
| `test-export_tfl_page.R` | `export_tfl_page()` — argument resolution from x, overlap_warn_mm, page_i prefix, section presence, rules |
| `test-table_utils.R` | `.compute_group_sizes()`, `.collect_col_strings()`, `.measure_max_string_width()`, `.wrap_text()` |
| `test-table_draw.R` | `build_table_grob()`, `drawDetails.tfl_table_grob()` (uncached fallback, wrap branch, rotated col_cont_msg labels, first_data fallback) |
| `test-tfl_table.R` | `tfl_colspec()`, `tfl_table()`, column/row pagination, column width calculation, col_cont_msg flags, `tfl_table_to_pagelist()` |
| `test-gt.R` | `.extract_gt_annotations()`, `.clean_gt()`, `gt_to_pagelist()`, `export_tfl.gt_tbl()`, `export_tfl.list()` with gt_tbl objects, S3 dispatch |
| `test-integration.R` | Multi-file end-to-end smoke tests spanning the full pipeline |

---

## `test-normalize.R` — `normalize_text()`, `normalize_rule()`

```r
# normalize_text()
test_that("normalize_text returns NULL for NULL input", ...)
test_that("normalize_text handles single string", ...)
test_that("normalize_text collapses character vector with \\n", ...)
test_that("normalize_text counts embedded newlines in nlines", ...)
test_that("normalize_text counts lines in collapsed vector correctly", ...)
test_that("normalize_text handles empty string", ...)
test_that("normalize_text handles character(0)", ...)

# normalize_rule()
test_that("normalize_rule returns FALSE for FALSE", ...)
test_that("normalize_rule returns linesGrob for TRUE", ...)
test_that("normalize_rule returns linesGrob for numeric 0.5", ...)
test_that("normalize_rule errors for numeric outside (0,1]", ...)
test_that("normalize_rule passes linesGrob through unchanged", ...)
test_that("normalize_rule errors for invalid input type", ...)
```

---

## `test-resolve_gp.R` — `resolve_gp()`, `merge_gpar()`

```r
# merge_gpar()
test_that("merge_gpar returns override fields when both present", ...)
test_that("merge_gpar returns base fields absent from override", ...)
test_that("merge_gpar with empty override returns base", ...)
test_that("merge_gpar with empty base returns override", ...)

# resolve_gp()
test_that("resolve_gp returns gpar() when gp is bare gpar and no match", ...)
test_that("resolve_gp uses global gpar when gp is bare gpar", ...)
test_that("resolve_gp uses section-level gp over global", ...)
test_that("resolve_gp uses element-level gp over section-level", ...)
test_that("resolve_gp uses element-level gp over global", ...)
test_that("resolve_gp handles missing section key gracefully", ...)
test_that("resolve_gp handles missing element key gracefully", ...)
```

---

## `test-overlap.R` — `check_overlap()`

```r
test_that("check_overlap returns no errors when content fits", ...)
test_that("check_overlap errors when left and center overlap", ...)
test_that("check_overlap errors when right and center overlap", ...)
test_that("check_overlap errors when left and right overlap (no center)", ...)
test_that("check_overlap warns on near-miss within overlap_warn_mm", ...)
test_that("check_overlap does not warn when gap >= overlap_warn_mm", ...)
test_that("check_overlap skips all checks when overlap_warn_mm is NULL", ...)
test_that("check_overlap handles absent center element (NULL width)", ...)
test_that("check_overlap handles all three absent (no-op)", ...)
```

---

## `test-layout.R` — `compute_figure_height()`, `check_figure_height()`

```r
test_that("figure height equals vp_height when no other sections", ...)
test_that("figure height subtracts header and padding correctly", ...)
test_that("figure height subtracts header + caption + 2 paddings", ...)
test_that("figure height subtracts all sections and correct padding count", ...)
test_that("padding count is 0 when only content is present", ...)
test_that("padding count is 1 when header and content present", ...)
test_that("padding count is 4 when all 5 sections present", ...)
test_that("rules do not subtract from content height", ...)
test_that("check_figure_height adds error when h < min_content_height", ...)
test_that("check_figure_height does not add error when h >= min", ...)
test_that("error message includes actual and minimum heights", ...)
```

---

## `test-validate.R` — `validate_file_arg()`, `coerce_x_to_pagelist()`

```r
# validate_file_arg()
test_that("validate_file_arg errors on non-character file", ...)
test_that("validate_file_arg errors on length > 1 file", ...)
test_that("validate_file_arg errors when file does not end in .pdf", ...)
test_that("validate_file_arg passes for valid .pdf path", ...)
test_that("validate_file_arg passes for relative path ending in .pdf", ...)

# coerce_x_to_pagelist()
test_that("coerce_x_to_pagelist wraps single ggplot in list(list(content=x))", ...)
test_that("coerce_x_to_pagelist wraps single grob in list(list(content=x))", ...)
test_that("coerce_x_to_pagelist passes through list of page specs", ...)
test_that("coerce_x_to_pagelist errors if list element has no 'content'", ...)
test_that("coerce_x_to_pagelist errors if content is not ggplot or grob", ...)
```

---

## `test-measure.R` — `measure_grob_width()`

```r
test_that("measure_grob_width returns 0 for NULL grob", ...)
test_that("measure_grob_width returns positive width for a real text grob", ...)
```

Note: `measure_grob_width()` requires an open graphics device; tests open a
scratch PDF device before calling it.

---

## `test-table_utils.R` — internal table helpers

```r
# .compute_group_sizes()
test_that(".compute_group_sizes returns integer(0) for a zero-row data frame", ...)
test_that(".compute_group_sizes returns integer(0) when group_vars is empty", ...)

# .collect_col_strings()
test_that(".collect_col_strings truncates to max_rows unique strings", ...)

# .measure_max_string_width()
test_that(".measure_max_string_width returns 0 for an empty character vector", ...)

# .wrap_text()
test_that(".wrap_text returns an empty string unchanged", ...)
test_that(".wrap_text returns a single word unchanged regardless of width", ...)
test_that(".wrap_text inserts newlines when multi-word text overflows", ...)
test_that(".wrap_text preserves explicit paragraph breaks", ...)
test_that(".wrap_text handles an empty paragraph (blank line between lines)", ...)
test_that(".wrap_text handles a whitespace-only paragraph (all words stripped)", ...)
test_that(".wrap_text returns a long unbreakable token unchanged", ...)
test_that(".wrap_text wraps after an unbreakable first word", ...)
```

All tests requiring font metrics use a `with_vp()` helper that opens a scratch
PDF device, pushes a viewport, runs the expression, then in a single
`on.exit` block runs `popViewport()` before `dev.off()` (order is critical —
see Testing Notes below).

---

## `test-table_draw.R` — `build_table_grob()`, `drawDetails.tfl_table_grob()`

```r
# drawDetails — uncached height fallback
test_that("drawDetails recomputes cont_row_h and row_h_vec when not cached", {
  # build_table_grob() with row_heights_in = NULL, cont_row_h_in = NULL
  # includes a wrap-eligible column to exercise the .wrap_text branch
  # in the row-height fallback loop
})

# drawDetails — wrap_text in per-cell draw loop
test_that("drawDetails calls .wrap_text for wrap-eligible columns during draw", ...)

# drawDetails — rotated col_cont_msg side labels
test_that("drawDetails renders rotated col_cont_msg without error", {
  # 5 × 3-inch columns on 11-inch page forces >1 column page
  # exercises both is_last_col_page = FALSE (right label)
  # and is_first_col_page = FALSE (left label)
})

# .draw_cont_row() — first_data fallback
test_that(".draw_cont_row falls back first_data to 1 when all cols are group cols", {
  # single-column table where the column is the group variable;
  # tiny page forces continuation rows
})

# drawDetails — row_rule between data rows
test_that("drawDetails renders row_rule lines between data rows", ...)

# drawDetails — cell background shading via gp$fill
test_that("drawDetails renders header_row fill background", ...)
test_that("drawDetails renders alternating data_row fill per row", ...)
test_that("drawDetails renders alternating data_row fill per group", ...)
test_that("drawDetails renders single data_row fill without alternation", ...)
```

---

## `test-tfl_table.R` — `tfl_colspec()`, `tfl_table()`, pagination

Key areas covered:

- `tfl_colspec()` validation (bad col, bad label, bad wrap)
- `tfl_table()` validation: zero-column df, `cols` not a list, non-colspec
  element, unnamed/bad-name `col_widths`/`col_labels`/`col_align`,
  bad `wrap_cols` type, bad `col_cont_msg`/`row_cont_msg`/`na_string`/`gp`/
  `line_height`/`max_measure_rows`, bad `cell_padding`
- Column group flags: `is_first_col_page` / `is_last_col_page` set correctly
  on grobs when column split occurs; `col_cont_msg` NOT injected into
  `footer_center` (new behaviour post D-23)
- `paginate_cols()`: n_data == 0, balance paths, overflow fallback, single page,
  odd column counts, many columns (20), multiple group cols prepended
- `.apply_col_wrapping()`: no-eligible break path
- `measure_row_heights_tbl()`: `max_measure_rows` sampling, wrap path
- `tfl_table_to_pagelist()`: full pipeline smoke test, group validation,
  allow_col_split = FALSE error

---

## `test-gt.R` — gt connector

All tests wrapped in `skip_if_not_installed("gt")`.

```r
# .extract_gt_annotations()
test_that("title + subtitle → caption with newline separator", ...)
test_that("title only → caption without subtitle", ...)
test_that("no title → NULL caption", ...)
test_that("source notes → footnote", ...)
test_that("multiple source notes are combined", ...)
test_that("cell footnotes → footnote", ...)
test_that("source notes + cell footnotes combined", ...)
test_that("no annotations → NULL caption and NULL footnote", ...)

# .clean_gt()
test_that(".clean_gt removes title, source notes, and footnotes", ...)

# gt_to_pagelist()
test_that("gt_to_pagelist returns page spec with content and annotations", ...)
test_that("gt_to_pagelist with no annotations omits caption/footnote", ...)

# export_tfl.gt_tbl() — end-to-end
test_that("export_tfl writes PDF from gt_tbl", ...)
test_that("export_tfl preview mode works with gt_tbl", ...)
test_that("export_tfl.gt_tbl passes dots as defaults", ...)

# export_tfl.list() with gt_tbl objects
test_that("list of gt_tbl objects → multi-page PDF", ...)
test_that("list of gt_tbl preview renders all pages", ...)
test_that("list of mixed types falls through to default", ...)

# S3 dispatch
test_that("export_tfl dispatches to gt_tbl method", ...)
test_that("export_tfl dispatches to list method", ...)
```

---

## `test-integration.R` — end-to-end smoke tests

All integration tests that write a file use `tempfile(fileext = ".pdf")` and
confirm the file is created and non-empty.

Key areas covered:

**Basic rendering:**
- single ggplot → PDF
- single grob → PDF
- grob in page list → PDF
- multi-page list of ggplots → PDF

**Text sections:**
- `header_left` + `footer_right`
- all 6 header/footer elements
- `caption`, `footnote`
- multi-line caption as character vector
- multi-line caption with embedded `"\n"`
- multi-line footnote

**Rules:**
- `header_rule = TRUE`
- `footer_rule = 0.5`
- `header_rule` as `linesGrob`

**Page numbering:**
- `page_num` glue substitution
- `footer_right` in `x[[i]]` overrides `page_num`
- `page_num = NULL` disables auto-numbering

**Typography:**
- `gp` as bare `gpar()`
- `gp` as named list (section + element level)

**Device lifecycle:**
- `export_tfl` closes device on error mid-loop
- `export_tfl` returns invisible path (normal mode)

**Preview mode:**
- `preview = TRUE` draws to current device, returns `NULL` invisibly
- `preview = TRUE` with grob content
- `preview = TRUE` with full layout
- `preview = c(1L, 3L)` renders only selected pages
- `preview = 99L` aborts with "out of range" message
- `preview = TRUE` with `tfl_table` renders without writing file
- `preview = 1L` on `tfl_table` renders first page

**Error handling:**
- non-ggplot non-grob content raises informative error
- `export_tfl_page` layout error has no page prefix when `page_i` not supplied
- content height too short → `"Content height"` error
- overlap near-miss → warning not error
- invalid file extension → error before device opens
- `x` with no `content` element → informative error

---

## Testing notes

### Device state

Many grid tests require an open graphics device and an active viewport. Use
the `with_vp()` helper pattern from `test-table_utils.R`:

```r
with_vp <- function(expr) {
  f <- tempfile(fileext = ".pdf")
  grDevices::pdf(f, width = 11, height = 8.5)
  vp <- grid::viewport(width  = grid::unit(10, "inches"),
                       height = grid::unit(7.5, "inches"))
  grid::pushViewport(vp)
  on.exit({
    grid::popViewport()    # MUST run before dev.off()
    grDevices::dev.off()
    unlink(f)
  })
  force(expr)
}
```

**Critical:** `popViewport()` must run before `dev.off()`. If `dev.off()` runs
first it destroys the viewport stack and `popViewport()` throws
`"cannot pop the top-level viewport"`.

### Coverage tooling

```r
# Check coverage
covr::package_coverage()

# Find any uncovered lines precisely
covr::zero_coverage(covr::package_coverage())
```

Any line that genuinely cannot be covered (e.g., unreachable error branches
in S3 dispatch, future extension comments) should be marked:

```r
# 1-2 lines:
some_code()  # nocov

# 3+ lines:
# nocov start
...
# nocov end
```

### Error message matching

Use `expect_error(..., regexp = "...")` with the patterns defined in
`ARCHITECTURE.md` under "Error messages".

### `rlang::warn()` matching

Use `expect_warning(..., regexp = "...")` for near-miss overlap tests.

### Viewport stack in `test-table_draw.R`

Tests that call `build_table_grob()` then `grid.draw()` must call
`compute_col_widths()` first to populate `$width_in` on each resolved column
spec. Without `width_in`, `drawDetails` will fail when computing `col_widths_in`.

---

## What is NOT tested

- Visual appearance / pixel accuracy (see D-18)
- Font metric accuracy across platforms (platform-dependent)
- PDF file structure validity (use a PDF reader for manual spot-checks)
- Performance on large numbers of pages or columns
- `recordedPlot` / base R plot dispatch (not yet implemented)
