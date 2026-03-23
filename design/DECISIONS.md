# Decision Log — writetfl

Chronological record of design decisions, alternatives considered, and why
each choice was made. Cross-reference with `DESIGN.md` for deeper rationale.

---

## D-01: Use `grid` viewports rather than `plot.margin` alone

**Decision:** Two-level viewport stack (`outer_vp` → `content_vp`) for all
page layout.

**Alternatives considered:**
- `ggplot2::theme(plot.margin = ...)` alone — cannot reserve space outside the
  ggplot grob for running headers/footers
- `cowplot::ggdraw()` / `patchwork` — add ggplot-layer dependencies; no
  absolute-unit control at the page level

**Chosen because:** grid viewports are the native coordinate system underlying
both ggplot2 and the PDF device. They give absolute-unit control with no
additional dependencies.

---

## D-02: `draw_content()` accepts both ggplot and grob; errors for others

**Decision:** `draw_content()` has an ggplot branch, a grob branch, and an
error for anything else, with a comment marking the extension point.

**Alternatives considered:**
- Accept ggplot only — excludes `tfl_table` grobs and externally built grobs
  (gt, gridExtra, etc.)
- Accept `recordedPlot` — `replayPlot()` inside a viewport is finicky and
  requires the `gridGraphics` dependency

**Chosen because:** grob support is needed for the `tfl_table` subsystem. The
dispatch hook costs nothing and makes future generalization (e.g.,
`recordedPlot`) a one-function change.

---

## D-03: `gp` accepts single `gpar()` or named list at any granularity

**Decision:** Three-level hierarchy: global → section → element.

**Alternatives considered:**
- Single `gpar()` only — too coarse for mixed font sizes (bold header, small
  footer)
- Separate `header_gp`, `caption_gp`, etc. arguments — 8+ arguments just
  for typography
- Full CSS-style cascade — overly complex for an R package

**Chosen because:** Named list with granular override is idiomatic in R
(similar to `ggplot2::theme()` element inheritance) and covers all practical
use cases.

---

## D-04: `footer_right` beats `page_num`

**Decision:** `footer_right` (from `x[[i]]` or `...`) always wins over
`page_num`.

**Initial proposal:** `page_num` would win.

**Changed because:** User explicitly requested this. Rationale: `page_num` is
a convenience default; `footer_right` is an explicit override. Title pages or
unnumbered pages can suppress the page number by setting `footer_right = NULL`.

---

## D-05: `x[[i]]` beats direct arguments to `export_tfl_page()`

**Decision:** Precedence is `x[[i]]` > `...` > function defaults.

**Rationale:** `x` is the primary data source (programmatically generated page
specs). Direct arguments are defaults applied to all pages. This matches the
ggplot2 idiom where layer-level aesthetics override plot-level defaults.

---

## D-06: Rules fit inside padding, do not add space

**Decision:** Rules are drawn at the vertical midpoint of the padding gap.

**Alternative considered:** Rules add their own space (e.g., a `rule_height`
argument).

**Rejected because:** Adding space would mean enabling a rule changes content
height, breaking layout consistency across pages.

---

## D-07: Accept any grob for rules

**Decision:** `header_rule` and `footer_rule` accept `FALSE`, `TRUE`, numeric,
or any grob (typically a `linesGrob`).

**Rationale:** Avoids `header_rule_gp`, `header_rule_lty`, `header_rule_col`
argument explosion. Power users get full control; simple users use `TRUE`.
Accepting any grob (not just `linesGrob`) allows decorative rules without
artificial type restrictions.

---

## D-08: Error collection before drawing

**Decision:** All layout errors are collected into a character vector; a single
`rlang::abort()` is called before any drawing begins.

**Alternative considered:** Error on first violation.

**Rejected because:** Drawing to a PDF device is not transactional. Partial
draws leave the device in an inconsistent state. Collecting errors and aborting
before drawing ensures pages are either fully drawn or not touched.

---

## D-09: `normalize_text()` returns `list(text, nlines)`

**Decision:** Normalization and measurement are separated.

**Alternative considered:** `measure_grob_height()` does its own string
parsing.

**Rejected because:** Entangles concerns. Separate functions are independently
testable.

---

## D-10: Height measurement uses `max(grobHeight, nlines * stringHeight("M"))`

**Decision:** Conservative maximum of two estimates.

**Rationale:** `grobHeight()` on multi-line `textGrob` is unreliable across
platforms. The fallback `nlines * stringHeight("M")` is a conservative
cap-height proxy. Taking the max ensures text is never clipped.

---

## D-11: `on.exit(dev.off(), add = TRUE)`

**Decision:** `add = TRUE` is mandatory.

**Rationale:** Preserves any `on.exit` handlers registered by the caller.
Without `add = TRUE`, our handler would replace the caller's, potentially
causing resource leaks.

---

## D-12: Return `invisible(normalizePath(file, mustWork = FALSE))`

**Decision:** Absolute path returned invisibly.

**Rationale:**
- `invisible()` — no console noise in normal use
- `normalizePath(..., mustWork = FALSE)` — resolves relative paths before file
  exists, enabling downstream use (e.g., `browseURL()`)

---

## D-13: `overlap_warn_mm = NULL` disables overlap detection

**Decision:** Passing `NULL` skips all overlap checks.

**Use case:** Programmatic layouts where the caller has pre-verified content
fits, or layouts with no header/footer text elements.

---

## D-14: `caption_just` and `footnote_just` as explicit arguments

**Decision:** Separate `caption_just` / `footnote_just` arguments defaulting
to `"left"`.

**Alternative considered:** Control via `gp` — but `gpar()` has no
justification field.

**Chosen because:** `textGrob`'s `just` argument is separate from `gp`.
Adding explicit arguments is cleaner than a parallel `caption_gp_just`
approach.

---

## D-15: Package named `writetfl`

**Decision:** Package name is `writetfl`.

**Rationale:** Communicates the domain (TFL = Tables, Figures, Listings;
write = export to file). The function prefix `tfl_` signals domain membership
throughout the API.

---

## D-16: `min_content_height` defaults to `unit(3, "inches")`

**Decision:** 3-inch minimum content height.

**Rationale:** A content area shorter than 3 inches is typically unreadable
in a regulatory/clinical report context. This conservative default catches
layout mistakes early.

**Changed from initial proposal:** Initial suggestion was `unit(1, "inches")`;
changed to `unit(3, "inches")` per author's request.

---

## D-17: `margins` defaults to 0.5 inches, not "lines"

**Decision:** `unit(c(t=0.5, r=0.5, b=0.5, l=0.5), "inches")`.

**Rationale:** `"lines"` is relative to current font size, which is device-
and platform-dependent at the root viewport. Absolute units (`"inches"`) are
reproducible. The 0.5-inch value meets typical regulatory submission margin
requirements.

---

## D-18: No visual regression tests (`vdiffr` not included)

**Decision:** Test suite covers unit logic and integration smoke tests only;
no snapshot/visual regression tests.

**Rationale:** Visual regression tests require a stable reference rendering
environment and add significant CI complexity. The test suite verifies that
layout computation is correct and drawing completes without error. Visual
correctness is verified manually during development. **100% line coverage is
maintained** via `covr::package_coverage()`.

---

## D-19: No base R plot support

**Decision:** `x$content` must be a ggplot or grid grob; base R plots are not
supported.

**Rationale:** `replayPlot()` inside a grid viewport requires `grid.echo()`
from the `gridGraphics` package, adding a dependency for a niche use case. The
`draw_content()` dispatch hook makes this a future opt-in.

---

## D-20: `tfl_table()` defers all measurement to `export_tfl()` call time

**Decision:** `tfl_table()` stores configuration only. Column widths, row
heights, and pagination run in `tfl_table_to_pagelist()`, which is called by
`export_tfl()` when page dimensions and annotations are known.

**Alternative considered:** Measure at `tfl_table()` call time with default
dimensions.

**Rejected because:** The available content area depends on page dimensions,
margins, and annotation content — none of which is known at `tfl_table()` call
time. Deferring guarantees pagination is consistent with actual output.

---

## D-21: Row heights are cached in the `tfl_table_grob` gTree

**Decision:** Pre-computed `row_heights_in` and `cont_row_h_in` are stored in
the gTree so `drawDetails` reuses them without remeasuring.

**Alternative considered:** Remeasure on every draw.

**Rejected because:** Remeasuring at draw time would require opening a scratch
device inside `drawDetails`, which is fragile. Caching ensures layout
consistency between pagination and rendering. Fallback re-measurement is
retained for grobs constructed outside `tfl_table_to_pagelist()` (e.g., in
tests).

---

## D-22: Column-split pagination prepends group columns to every page

**Decision:** Group (row-header) columns appear at the left of every column
page, with their indices prepended to each column group vector in
`paginate_cols()`.

**Alternative considered:** Show group columns only on the first column page.

**Rejected because:** Group columns provide context for reading data rows. A
reader encountering a non-first column page without group columns would not
know which row group they are in.

---

## D-23: `col_cont_msg` rendered as rotated side labels, not footer text

**Decision:** Column continuation messages are drawn as rotated `grid.text`
labels inside the table grob's viewport: clockwise 90° to the right when
columns continue on a later page, counter-clockwise 90° to the left when
columns continue from a prior page.

**Previous behaviour:** `col_cont_msg` was injected into `footer_center` of
the page spec by `tfl_table_to_pagelist()`.

**Changed because:**
1. Footer injection silently overrode any user-supplied `footer_center`.
2. A table-internal message belongs visually near the table, not in the page
   footer.
3. Rotated labels are self-contained in the grob and do not affect page-level
   annotation.

**Implementation:** `build_table_grob()` now accepts `is_first_col_page` and
`is_last_col_page` flags. `drawDetails.tfl_table_grob()` uses them to decide
which labels to draw, with `%||% TRUE` defensive fallback for grobs built
outside `tfl_table_to_pagelist()`.

---

## D-24: `export_tfl()` preview mode returns `invisible(NULL)`, not grobs

**Decision:** After drawing all preview pages, `export_tfl()` returns
`invisible(NULL)`.

**Previous behaviour:** Returned `invisible(list_of_grobs)` captured via
`grid::grid.grab()` after each page.

**Changed because:** `grid.grab()` after drawing caused a **double-render
bug** — the figure appeared twice in knitr/RStudio output. The captured grob
was being processed and rendered a second time by the output pipeline. Since
preview mode is a side-effect operation (the draw is the goal), removing
`grid.grab()` is the correct fix. Users who need to capture rendered output
should use the graphics device directly.

---

## D-25: Test coverage target is 100% line coverage

**Decision:** All source lines are covered by `testthat` tests; any line that
cannot reasonably be tested (e.g., unreachable error branches in external
dispatch) is marked with `# nocov` or bracketed with `# nocov start` /
`# nocov end`.

**Rationale:** 100% coverage was achievable given the deterministic,
side-effect-light design of most helpers. Enforcing it during development
prevents silent regressions in edge-case branches.

**Tooling:** `covr::package_coverage()` + `covr::zero_coverage()` to identify
uncovered lines precisely.

---

## D-26: One test file per source file

**Decision:** Tests in `tests/testthat/test-<name>.R` correspond exactly to
`R/<name>.R` source files.

**Alternative considered:** Combined test files (e.g., `test-table.R` covering
all table_*.R files).

**Rejected because:** Co-location makes it easy to find the tests for any
given source file and keeps test files from growing unwieldy. This also aligns
with standard `{usethis}` / `{testthat}` convention.

---

## D-27: Use `checkmate` for input validation

**Decision:** Add `checkmate` as an Import and use its assertion functions
(`assert_string`, `assert_flag`, `assert_data_frame`, `assert_number`,
`assert_class`, `assert_character`) to replace hand-rolled validation in
`tfl_colspec()` and `tfl_table()`. Delete the internal `.assert_flag()` helper.

**Why:** The package had ~20 hand-rolled input checks with repetitive
`if (!is.X(arg) || length(arg) != 1L || ...) abort(...)` patterns. `checkmate`
is lightweight (depends only on `backports`), is widely used in the clinical R
ecosystem (1800+ CRAN reverse dependencies), and provides consistent,
informative error messages with argument-name context via `.var.name`.

**What stays hand-rolled:** Validation for union types (`width`: unit or
positive numeric; `gp`: gpar or list; `wrap_cols`: logical or character),
group-column ordering checks, the `cols` list validation loop with per-element
index messages, and `.normalise_cell_padding()`.

**Alternative considered:** Keep all validation hand-rolled.

**Rejected because:** The maintenance cost of ~150 lines of boilerplate
validation exceeds the cost of a well-established, lightweight dependency.

---

## D-28: Re-measure text width at draw time for preview clipping

**Decision:** `.draw_cell_text()` re-measures text width in the current
(rendering) device at draw time and uses `max(cached_column_width,
remeasured_text_width)` for the clipping viewport width. This is fully
device-agnostic since `drawDetails` runs in the rendering device.

**Problem:** Column widths measured in a PDF scratch device use PDF-specific
font metrics. When the table grob is later rendered on a PNG device (e.g. in
a knitr vignette), the PNG device's font rendering backend (Windows GDI on
Windows, Cairo/FreeType on Linux) can produce slightly wider text. The
clipping viewport in `.draw_cell_text()` hard-clips to the cached column
width, causing visible text truncation (e.g. "System Organ Class" clipped on
left and right edges).

**Previous approach (superseded):** Device-matched scratch devices that used
`grDevices::png()` for preview mode instead of `grDevices::pdf(NULL)`,
threading `for_preview` and `scratch_dpi` through 6 function signatures.
This was fragile and didn't reliably fix the clipping.

**Current approach:** All scratch devices use `grDevices::pdf(NULL, ...)`.
At draw time, `.draw_cell_text()` calls `grid::stringWidth()` to re-measure
the text in the rendering device. The clipping viewport uses the wider of
the cached column width and the re-measured text width. For PDF output, the
re-measurement matches the cached value (no change). For PNG/raster preview,
the re-measurement reflects the actual rendering font metrics, preventing
clipping.

**Alternatives considered:**

- *Add a padding buffer to column widths* — rejected because it wastes space
  and the correct buffer size varies across platforms and fonts.
- *Remove `clip = "on"` from cell viewports* — rejected because it allows
  text to bleed into adjacent columns for fixed-width columns.
- *Device-matched scratch devices* — superseded (see above).

---

## D-29: `row_rule` parameter for horizontal data-row rules

**Decision:** Add `row_rule = FALSE` to `tfl_table()`. When `TRUE`, a
horizontal rule is drawn between every pair of consecutive data rows (not
after the last row). Style is controlled via `gp$row_rule`.

**Alternative considered:** Reuse `group_rule` for all rows — rejected
because group rules and row rules serve different purposes and need
independent styling (e.g., dotted for group boundaries, solid for rows).

**Alternative considered:** Draw a rule after the last row too — rejected
because the last row is followed by either a continuation row or the table
edge, where a rule would be redundant.

**Implementation:** Follows the exact same drawing pattern as `group_rule`
in `drawDetails.tfl_table_grob()`: compute `y_rule_npc`, `x_left_npc`,
`x_right_npc`, call `grid::grid.lines()`. Default gpar is `lwd = 0.5`
(thin solid line).

---

## D-30: Cell background shading via `gp$fill` and `fill_by`

**Decision:** Background fill colors are controlled through the existing
`gp$header_row` and `gp$data_row` gpar keys using the `fill` field.
A new `fill_by` parameter on `tfl_table()` controls whether fill color
vectors alternate per `"row"` (default) or per `"group"`.

**Alternatives considered:**
- Dedicated `header_bg` / `data_bg` parameters — rejected because it
  adds new top-level parameters when gpar already has a `fill` field.
- Separate `bg_colors` parameter — rejected for the same reason; gpar
  is the natural place for visual properties.

**Implementation:**
- `gp$header_row = gpar(fill = "lightblue")` fills the header row
- `gp$data_row = gpar(fill = c("white", "gray95"))` alternates colors
- `fill_by = "group"` advances the color index at group boundaries
  instead of at every row, enabling banded group shading.

Background rectangles are drawn before cell text so text renders on top.
The fill is extracted from the resolved gpar at draw time; if `fill` is
NULL (the default), no rectangle is drawn.

---

## D-31: S3 generic `export_tfl()` and ggtibble connector

**Decision:** Convert `export_tfl()` from a plain function to an S3 generic
with `UseMethod()`. The existing `if/else` dispatch becomes three methods:
`export_tfl.default()` (ggplot, grob, list), `export_tfl.tfl_table()`, and
`export_tfl.ggtibble()`. Shared page-rendering logic is extracted into
`.export_tfl_pages()`.

**ggtibble integration:** The `ggtibble` package is a soft dependency
(Suggests). `ggtibble_to_pagelist()` converts each row to a page spec:
- `figure` column → `content` (ggplot extracted from gglist)
- Any column matching an `export_tfl_page()` text argument name (`caption`,
  `footnote`, `header_left`, etc.) → used as that argument's per-page value
- Other columns (`data_plot`, outer grouping cols) are ignored

**Column mapping is by convention:** column names must exactly match
`export_tfl_page()` parameter names. No explicit mapping arguments.

**Alternative considered:** Keep `inherits()` dispatch in the function body.
Rejected because S3 generics are the idiomatic R pattern and allow
third-party packages to add methods without modifying writetfl source.

---

## D-32: gt connector — annotation extraction and grob rendering

**Decision:** `export_tfl.gt_tbl()` extracts gt metadata (title/subtitle →
caption, source notes + cell footnotes → footnote), strips them from the gt
object via `rm_header()` / `rm_source_notes()` / `rm_footnotes()`, then
converts the cleaned table to a grob via `gt::as_gtable()`.

**Alternatives considered:**
- Render gt to HTML/image and embed — loses vector quality and annotation
  control.
- Use gt's built-in PDF export — no writetfl page layout integration.
- Parse the gt object's internal data frame and rebuild as `tfl_table()` —
  would lose gt-specific formatting (spanners, merged cells, etc.).

**Chosen because:** `gt::as_gtable()` produces a grid grob that drops
directly into writetfl's viewport system. Extracting annotations into
writetfl's zones avoids duplication (gt would render them inside the grob,
and writetfl would render them in the annotation zones).

**gt is a soft dependency** (Suggests only). `rlang::check_installed("gt")`
is called at the top of each gt-related method.

**`export_tfl.list()`** detects lists where all elements are `gt_tbl` and
converts each independently via `gt_to_pagelist()`.

**Phase 1:** Single-page rendering with annotation extraction.
**Phase 2:** Row-group pagination — measures grob height, computes available
content area, and greedily splits rows at group boundaries. Sub-gt objects
are rebuilt with `.rebuild_gt_subset()` preserving column labels, options,
`_formats` (re-indexed), and `_styles` (re-indexed).
**Phase 3/4:** `.rebuild_gt_subset()` also copies `_transforms`,
`_substitutions`, and `_summary` (filtered to groups present in subset).
Spanners, `cols_merge()`, and `summary_rows()` all survive pagination.

---

## Open questions / future work

- Support for `recordedPlot` in `draw_content()` (requires `gridGraphics`)
- Support for `patchwork` / `cowplot` compound figures in `draw_content()`
- `header_rule_gp` / `footer_rule_gp` shorthand arguments (currently via
  `linesGrob` examples)
- Multi-column layout (figure + sidebar)
- Landscape vs. portrait per-page switching
- Horizontal cell borders (`col_header_rule` and `row_rule` exist; per-cell
  borders are not yet implemented)
- `tfl_table` cell-level gpar overrides (beyond group vs. data col distinction)
