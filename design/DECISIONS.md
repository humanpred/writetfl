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
**Phase 3/4:** `.rebuild_gt_subset()` preserves all gt metadata through
pagination. Row-indexed slots (`_formats`, `_styles`, `_substitutions`,
`_transforms`) are re-indexed to the subset's row positions. Structural
slots (`_boxhead`, `_options`, `_spanners`, `_stubhead`, `_locale`,
`_summary_cols`) are copied as-is. `_summary` is filtered to groups
present in the subset. Spanners, `cols_merge()`, `summary_rows()`,
`sub_*()`, `text_transform()`, `tab_options()`, and locale all survive
pagination.

Note: `_substitutions` and `_transforms` were initially copied without
re-indexing but this caused row-count mismatches — both have `$rows` /
`$resolved$rows` fields that reference original row indices.

---

## D-33: rtables connector — toString + textGrob rendering

**Decision:** Convert rtables `VTableTree` objects to grid grobs via
`formatters::toString()` → `grid::textGrob()` with monospace font. Use
rtables' built-in `paginate_table()` for pagination.

**Alternatives considered:**
- Cell-by-cell grob construction from `matrix_form()` — 500+ lines, fragile,
  would replicate rtables' complex alignment, spanning, and indentation logic.
- Use `export_as_pdf()` directly — no writetfl page layout integration
  (headers, footers, captions, footnotes).

**Chosen because:** `toString()` + `textGrob()` is the same approach rtables'
own `export_as_pdf()` uses internally. It preserves all rtables features
(nested row groups, column splits, spanning, indentation, referential
footnotes, section dividers) with ~200 lines of code.

**Annotation extraction:** `main_title` + `subtitles` → caption;
`main_footer` + `prov_footer` → footnote. Cleared via replacement functions
(`main_title<-`, etc.) so `toString()` doesn't render them.

**Pagination:** Delegated entirely to `rtables::paginate_table()` via
computed `lpp`/`cpp` from content dimensions and font metrics. This is
simpler than the gt connector, which needed custom row-group pagination
with `.rebuild_gt_subset()`.

**S3/S4 dispatch:** `VTableTree` is an S4 virtual superclass. S3 dispatch
works because R's `inherits()` checks the S4 class hierarchy. Method
`export_tfl.VTableTree` catches both `TableTree` and `ElementaryTable`.

**`toString()` dispatch:** Must use `formatters::toString()` explicitly
because `base::toString()` would be called from the package namespace and
does not find the S4 method.

**rtables is a soft dependency** (Suggests only). Both `rtables` and
`formatters` are listed. `rlang::check_installed()` is called at the top
of each rtables-related method.

---

## D-34: flextable connector — gen_grob() rendering

**Decision:** Convert flextable objects to grid grobs via
`flextable::gen_grob()` with `fit = "width"`. Extract caption from
`set_caption()` and footer-row text from `footnote()` /
`add_footer_lines()` into writetfl's annotation zones.

**Alternatives considered:**
- Render flextable to image and embed — loses scalability and editability.
- Manual cell-by-cell construction — flextable already provides `gen_grob()`
  which handles all formatting.

**Chosen because:** `gen_grob()` is flextable's native grid renderer. It
produces a `flextableGrob` (inherits from `gTree`) that preserves all
formatting: borders, colours, backgrounds, merged cells, text styles,
themes, and cell content. This is the simplest connector — no complex
internal subsetting like gt, no toString conversion like rtables.

**Annotation extraction:** Caption from `ft$caption$value`. Footnotes
from footer rows (`ft$footer$content$data` matrix, concatenating chunk
`txt` values per row). Footer rows are removed via
`flextable::delete_rows()` to avoid duplication.

**Font handling:** Flextable defaults to "Arial" which is not available
on the standard PDF device. `.flextable_set_pdf_font()` replaces
non-standard fonts with "Helvetica" (a PDF base font) before
`gen_grob()` is called.

**Pagination:** Greedy row-based pagination similar to gt. Body rows
are incrementally added and sub-tables measured via `gen_grob()`. Height
is measured from `grob$ftpar$heights` (sum of per-row heights) since
`flextableGrob` does not support standard `grobHeight()`.

**Pagination limitation:** Per-cell formatting (from `color()`, `bg()`,
`bold()`, etc.) is NOT preserved when subsetting rows for pagination.
Flextable stores styles in internal structures that cannot be safely
subset. This is documented and acceptable since most clinical tables
fit on a single landscape page.

**flextable is a soft dependency** (Suggests only).
`rlang::check_installed()` is called at the top of each
flextable-related method.

---

## D-35: table1 connector — t1flex() conversion strategy

**Decision:** Convert `table1` objects to grid grobs via
`table1::t1flex()` → `flextable::gen_grob()`. Extract caption and
footnote from the table1 object's internal `"obj"` attribute (not from
the flextable) since `t1flex()` may or may not carry these through
consistently.

**Alternatives considered:**
- Use `as.data.frame()` and build a custom grob — loses all formatting
  (bold labels, indentation, borders, merged header cells).
- Parse the `obj$contents` matrices directly — would require rebuilding
  all visual formatting that `t1flex()` already handles.

**Chosen because:** `t1flex()` is the officially supported conversion path
from the table1 package. It faithfully reproduces the HTML formatting as
a flextable, including bold variable labels, indented summary statistics,
stratification headers with column spans, and borders. The existing
flextable infrastructure (`.flextable_to_grob()`, `.flextable_set_pdf_font()`,
`.rebuild_flextable_subset()`) is reused without modification.

**Annotation extraction:** `attr(t1_obj, "obj")$caption` → writetfl
caption zone; `attr(t1_obj, "obj")$footnote` → writetfl footnote zone.
Extracted before conversion to flextable for reliability.

**Group-aware pagination:** table1 output has a natural grouping structure
where each variable forms a "group" (bold label row + indented summary
rows). Pagination splits between groups rather than at arbitrary row
boundaries. Group boundaries are identified from the `obj$contents`
matrices (one matrix per variable, `nrow()` gives the row count per group).
If a single group exceeds the page height, falls back to row-by-row
splitting within that group.

**Both table1 and flextable are soft dependencies** (Suggests only).
`rlang::check_installed()` is called for both at the top of each
table1-related method.

---

## D-36: Caption/footnote automatic word wrapping

**Decision:** Automatically word-wrap caption and footnote text to fit within
the viewport width, using greedy line-breaking based on grid font metrics.

**Implementation:** A new helper `wrap_normalized_text()` in `normalize.R`
wraps a normalized text object to a given width in inches. It delegates to the
existing `.wrap_text()` helper in `table_utils.R`.

**Execution order:** Wrapping must occur **after** the viewport is pushed
(needs an active device for font metric measurement) but **before** grob
building and height measurement. This ensures that:
1. `build_section_grobs()` creates grobs from already-wrapped text
2. `measure_section_heights()` measures the wrapped (possibly taller) grobs
3. `compute_content_height()` correctly subtracts the wrapped annotation
   heights, giving the content area the right remaining space

Both `export_tfl_page()` and `compute_table_content_area()` (used by all
table connectors for pagination) follow this ordering.

**Alternatives considered:**
- Wrap at grob-build time — would require passing width context into
  `build_section_grobs()`, complicating its interface.
- Truncate with ellipsis — loses information; wrapping is more appropriate
  for multi-line captions/footnotes common in clinical reports.

**Chosen because:** Greedy wrapping preserves all text, matches the existing
`.wrap_text()` infrastructure used by `tfl_table`, and requires minimal code
changes (one new helper + insertion of wrap step in two locations).

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

## D-37: Character string/vector as page content

**Decision:** `x$content` (and bare `x` passed to `export_tfl()`) may be a
character string or character vector in addition to a ggplot or grid grob.
A character vector is collapsed with `"\n"` before rendering. Long lines are
word-wrapped to the content viewport width using `.wrap_text()`.

**Implementation:**
- `draw_content()` gains a third branch for `is.character(content)`, plus `gp`
  and `content_just` parameters.  Wrapping and rendering happen inside the
  pushed `content_vp`, so font metrics are available.
- `export_tfl_page()` gains `content_just = "left"` (validated via `match.arg`,
  per-page override via `x$content_just`). The content gp is resolved via
  `resolve_gp(gp, "content", "content")` and passed to `draw_content()`.
- `coerce_x_to_pagelist()` in `utils.R` accepts bare character as a top-level
  shorthand and allows `is.character(pg$content)` in the per-page guard.

**Why at draw time:** The content viewport width needed for wrapping is only
known once `content_vp` is built inside `export_tfl_page()`.  Converting to a
grob earlier (at coercion time) would require a device and width context that
are not available there.

**Typography:** Follows the existing `resolve_gp()` hierarchy.  Users can write
`gp = list(content = gpar(fontsize = 11))` to style character content
independently of annotation text.

**Justification:** `content_just` mirrors the `caption_just` / `footnote_just`
pattern (`match.arg` + per-page override).  Default is `"left"`.

**Alternatives considered:**
- Convert character to a `textGrob` at coercion time — requires opening a
  scratch device to measure wrapping width; complicates `coerce_x_to_pagelist`.
- Use `build_text_grob()` — designed for annotation grobs positioned via
  `editGrob()` in `outer_vp`; not appropriate for top-left-anchored content in
  its own viewport.

---

## D-38: `sub_tfl` argument for sub-tables and sub-figures

**Decision:** `tfl_table()` and `export_tfl.ggtibble()` accept a `sub_tfl`
character-vector argument naming columns to split the output by. Each unique
combination of values yields its own sub-table (or sub-figure page). The
sub_tfl values are removed from the rendered body and instead appended to the
caption as `"label: value; label: value"`. Three companion arguments —
`sub_tfl_sep` (default `": "`), `sub_tfl_collapse` (default `"; "`), and
`sub_tfl_prefix` (default `"\n"`) — control formatting.

**Behaviors:**
- **Body drop:** sub_tfl columns are always removed from the rendered table.
  This is unconditional — even if the user also lists a column in `cols` /
  `col_widths` / `col_labels` / etc., it is stripped before pagination.
- **Group-var overlap is allowed.** When a sub_tfl column also appears in
  `dplyr::group_vars(x)`, it is removed from `group_vars` (promoted to the
  caption). This is a common case (e.g. data already grouped by treatment
  arm; user wants one sub-table per arm).
- **Ordering:** factor columns drive ordering by their levels;
  character/numeric columns by first-appearance order. The combined order
  iterates `sub_tfl` left-to-right outer-to-inner.
- **NULL caption:** when the global caption is NULL, the suffix becomes the
  whole caption (no leading prefix).
- **Label source (tfl_table):** `tfl_colspec$label` if set, else
  `col_labels[col]` if named, else the raw column name. ggtibble uses raw
  column names only.
- **Recursion in `tfl_table_to_pagelist()`:** the sub_tfl branch loops over
  groups and calls `tfl_table_to_pagelist()` recursively (with `sub_tfl =
  NULL` on the inner table). This re-enters the existing measurement /
  pagination / drawing pipeline unchanged for each sub-group.
- **Per-page caption attachment:** each returned page spec carries its own
  `$caption`. `build_page_args()` (utils.R) already merges per-page values
  over the global `dots`, so no change is needed there.

**Why recursion rather than caption-only injection at the top level:** the
caption suffix has variable line count after word-wrap, which changes the
available content height. Each sub-group must therefore re-run
`compute_table_content_area()` with its own caption. Recursing through the
existing pipeline is the cleanest way to honour that and reuses every
existing helper.

**Alternatives considered:**
- **Single-pass with one shared content-area calculation** — would mis-size
  pages whenever sub_tfl values produce captions of different line counts
  (long vs. short labels, or factor levels with very different lengths).
- **Disallow group_vars overlap** — would force users to pre-`ungroup()` data
  that is already grouped by the same dimension they want to split on.
  Rejected as user-hostile and contrary to the most common use case.
- **List-of-`tfl_colspec` shape for sub_tfl** — overkill; labels and any
  per-column formatting can be inherited from the existing colspec system.
- **Magic prefix detection (e.g. columns starting with `sub_`)** — too
  implicit; explicit `sub_tfl =` argument is clearer and grep-able.
- **Sub-figures via raw `export_tfl()` (ggplot/grob input)** — out of scope.
  Figure users with by-group needs should build a `ggtibble`, which already
  has per-row caption support; `sub_tfl` augments that.

**Implementation:** new file `R/sub_tfl.R` holding `.compute_sub_tfl_groups()`,
`.format_sub_tfl_caption()`, `.apply_sub_tfl_caption()`,
`.strip_sub_tfl_cols()`, and `.resolve_col_label()` (factored out of
`resolve_col_specs()` so sub_tfl and the column-spec resolver share label
fallback logic).

---

## D-39: `overflow_action` for too-wide content (issue #30)

**Decision:** Add a single user-facing parameter
`overflow_action = c("error", "warn")` (default `"error"`) on
`export_tfl_page()` and forward it through `export_tfl()` and the
`tfl_table_to_pagelist()` pipeline. The same knob controls three width-overflow
detection sites: a new page-level grob check in `export_tfl_page()`, the
existing `tfl_table` total-width abort in `compute_col_widths()`, and a new
group-aware per-column check (also in `compute_col_widths()`).

**User need (from issue #30):** "When the content section is too wide for the
allocated area, give an error. That error should be convertible to a warning
so that output can be generated for diagnosis of the issue."

**Behavior:**
- `"error"`: append the message to the `errors` accumulator and abort via
  `rlang::abort(paste(errors, collapse = "\n"))`. No drawing occurs.
- `"warn"`: emit `rlang::warn()` immediately and continue. The PDF is
  produced with overflow visibly clipped by `grid` so the user can see what
  is too wide.

**Three detection sites, one knob:**
1. **Page-level grob check** (`export_tfl_page()`, validation phase): when
   `x$content` is a non-ggplot, non-character, non-`tfl_table_grob` grob,
   measure `grid::grobWidth(x$content)` while `outer_vp` is active and
   compare to `vp_width_in`. Catches `gt::as_gtable()`, `rtables` textGrobs,
   `gridExtra::tableGrob`, and raw user grobs. `tfl_table_grob` is excluded
   because the per-column check at site (3) below already validated the
   layout with finer-grained per-column information; re-checking the
   assembled grob would emit a redundant, less informative warning under
   `overflow_action = "warn"`.
2. **`tfl_table` total-width** (`compute_col_widths()`): the existing
   `allow_col_split = FALSE` abort now respects `overflow_action`.
3. **`tfl_table` group-aware per-column** (`compute_col_widths()`, new): for
   each group column j ≤ `n_group_cols`, signal if
   `widths_in[j] > content_width_in`; for each data column j > `n_group_cols`,
   signal if `grp_w + widths_in[j] > content_width_in`. The data-column rule
   is **group-aware** because group columns repeat on every column-paginated
   page, so a data column that doesn't fit alongside the row headers can
   never be rendered. Previously this case overflowed silently — grid
   clipped the column with no warning.

**Alternatives considered and rejected:**
- Boolean `strict_width = TRUE/FALSE`: less explicit and harder to extend
  with future severity levels.
- Numeric threshold `width_warn_mm` (mirroring `overlap_warn_mm`): conflates
  near-miss detection with the diagnostic-mode use case the user actually
  asked for.
- Three-level `c("error", "warn", "silent")`: silent overflow is the bug
  being fixed; leaving an opt-out re-opens it.
- Auto-promoting `allow_col_split = FALSE` → `TRUE` under `"warn"`: would
  override an explicit user choice. The cleaner mental model is that
  `allow_col_split` decides *whether* the total-width condition counts as an
  overflow event, and `overflow_action` decides *how* it is signaled.
- Merging `check_content_height()` and the new `check_content_width()` into
  a single `check_content_area()`: rejected because the two checks have
  structurally different signatures (height takes a `min_content_height`
  unit; width takes a viewport-width numeric and the action knob), different
  semantics (min-floor vs max-ceiling), and naming the dimension precisely
  reads better at the call site than `_area`. The shared part — the
  warn-vs-error dispatch — is factored into a small private
  `.overflow_signal()` helper instead.

**API placement:** Top-level `export_tfl_page()` argument (next to
`min_content_height`) rather than in `...` (where `overlap_warn_mm` lives),
because `overflow_action` changes error-vs-warning semantics and deserves a
documented top-level slot. `export_tfl()` picks it up automatically via
`@inheritDotParams export_tfl_page` (also adopted in this change), so the
docs stay in sync without manual duplication.

**Diagnostic hint in messages:** every overflow message — abort or warning —
ends with the literal hint
`Set `overflow_action = "warn"` to convert this error to a warning and still
produce output for diagnosis.` Centralized in the new private
`.overflow_signal()` helper in `R/layout.R`.

**`sub_tfl` ordering:** the per-column / group-aware check is positioned
inside `compute_col_widths()` (called from `.tfl_table_to_pagelist_default()`),
which is reached from `.tfl_table_to_pagelist_sub_tfl()` *after*
`.strip_sub_tfl_cols()` has removed the `sub_tfl` columns from the data and
from `group_vars`. So a `tfl_table` whose original group columns would
overflow only because they include columns later stripped by `sub_tfl` is
correctly accepted. A regression test in `tests/testthat/test-sub_tfl.R`
locks this ordering in.

**Backward compatibility:** the only behavior change for existing scripts is
that previously-silent overflow cases (single-column, group-aware, raw grob
content) now error by default. This is intentional — silent overflow is the
bug being fixed. Users who want the old behavior can pass
`overflow_action = "warn"` (or fix the underlying width issue).

**Files touched:**
- New: `.overflow_signal()`, `check_content_width()` in `R/layout.R`.
- Modified: `R/export_tfl_page.R` (new arg, validation phase, page-level
  grob check), `R/table_columns.R` (`compute_col_widths()` per-column +
  total-width checks), `R/table_pagelist.R` (thread the arg through),
  `R/export_tfl.R` (`@inheritDotParams`).

---

## D-40: Group-label rowspan-style flow (issue #29)

**Decision:** When a group column's value is multi-line, do not force its
row to be tall enough to fit the whole label.  Instead let the label flow
through the suppressed (blanked) cells in the rows below it the same way
HTML `<td rowspan="N">` reserves a single visually-spanning cell.

The implementation has three parts:

1. **Per-cell height matrix.**  `measure_row_heights_tbl()` now returns a
   `[nrow(data) × length(resolved_cols)]` matrix of cell heights instead
   of a per-row scalar vector.  Each entry includes `v_pad_in` so the
   per-row max equals the row height when no spanning happens.

2. **Span-aware per-page resolver `.compute_page_row_heights()`.**  Given
   the matrix, the rows on a page, the resolved columns, the group
   variable list, and the per-page suppression matrix, walk group columns
   from innermost to outermost and grow the first row of each span by any
   deficit between the label height and the sum of the span's row
   heights.  Innermost-first lets outer spans borrow inner-pass growth.
   First-row growth matches the label's top-anchored alignment in
   `.draw_cell_text()`.

3. **Per-page tentative recompute in `paginate_rows()`.**  The fit check
   uses `sum(.compute_page_row_heights(c(cur_rows, i), …))` rather than a
   running scalar accumulator.  This is required because span heights are
   non-monotone in row count (adding a row to an open span can leave the
   total unchanged or even shrink earlier-row contributions as the span's
   `avail` grows), and because the orphan case — when only the first row
   of a multi-row group lands on the current page — must size that row
   to fit the full label by itself.  `committed_rh` snapshots heights
   after each successful append so the flush at overflow uses the
   orphan-correct heights.

**User need (from issue #29):** "If there is a grouping column in a table
which will have empty rows under it, and the grouping column has multiple
rows of text, do not reserve space for the grouping column more than is
required.  Allow it to flow into the empty space below like a rowspan."
Plus: "if there is a grouping column on one page and different behavior
on the next page... the handling of the reserved height for column A will
differ between the pages."

**Default behaviour whenever suppression is active.**  The four
behavioural changes below all turn on together whenever
`suppress_repeated_groups = TRUE` (the package default).  No separate
opt-in flag — if the user has asked for suppression, they have asked
for the behaviour that makes suppression visually coherent:
1. span-aware row heights — group columns never inflate row heights;
   multi-line labels flow downward through the blanked cells below;
2. row-rule suppression within a multi-row span — a horizontal line
   that would slice a flowing label is skipped;
3. partial-width group rules — the rule line starts at the column for
   the outermost group_var level that actually changed at the
   transition, so unchanged outer columns through which the label is
   flowing aren't visually divided;
4. group rules drawn at *every* transition — the historical "skip rule
   when the new innermost group has size 1" check is bypassed because
   partial widths and label-flow alignment make single-row transitions
   visually unambiguous.

**Opt-out via `suppress_repeated_groups = FALSE`.**  Setting suppression
itself to `FALSE` reverts to the strict per-row layout: every group
cell renders fully on every row and each row's height is the per-row
max over every cell.  Group rules also revert to full-width.  This is
the only "off switch" — the design treats the rowspan flow as the
natural visual rendering of suppression, not a separate feature.

An earlier iteration of this branch added a `simplify_rowspan` flag
defaulting to `FALSE` (opt-in for the flow).  After review feedback
that the row-height behaviour should be the default whenever
suppression is on, the flag was removed: keeping it bifurcated the
mental model into three modes when one suffices.

**Suppression-aware row rule.**  The `row_rule` between data rows is
suppressed when the next row is part of a multi-row group span (any
suppressed group column on row `ri+1`).  A horizontal line slicing
through a label that flows downward would visually fragment it; HTML
rowspan also has no internal borders.  Group rules and
`group_rule_after_last` are unaffected because they only fire at group
boundaries (which are also span boundaries).

**Partial-width group rules.**  The group rule line starts at the
column corresponding to the *outermost* group-var level that actually
changed at the transition, not at column 1.  A new helper
`.compute_group_rule_info()` returns both the size and the
outermost-changing level per group_start; drawing reads the level to
set the line's left edge.  Concrete result for nested
`group_vars = c("Cohort", "Visit")`:

| transition | outermost changer | rule columns        |
| ---------- | ----------------- | ------------------- |
| Visit only | Visit (level 2)   | Visit, Value        |
| Cohort     | Cohort (level 1)  | Cohort, Visit, Value|

Partial-width rules apply regardless of `suppress_repeated_groups`,
because the rule semantically marks a change at the outermost-changing
level whether or not the unchanged levels' cells are suppressed.

**Alternatives considered and rejected:**
- *Distribute deficit evenly across rows of the span* — leaves wasted
  space below the (top-anchored) label in early rows.  First-row growth
  is both visually minimal and consistent with the alignment.
- *Vertically centre labels in the span* — aesthetic change orthogonal
  to the height-management problem.  Not in scope; can be added later
  via a `tfl_table` argument if a use case appears.
- *Span-aware row-fill rectangles* — currently each row paints its own
  background.  Painting a multi-row block under a span would be visually
  consistent with the label flow but conflicts with stripe shading
  (`fill_by = "row"`).  Out of scope; the per-row stripe is consistent
  with the body cells still being one-row each.
- *Cache only the per-page committed heights, not the full matrix* —
  pagination needs the matrix for its tentative recompute, drawing
  needs it for the fallback path.  Caching both the matrix on the grob
  and the committed heights on each page spec is cheap (matrices are
  small) and lets each consumer pick whichever is cheaper.

**Files touched:**
- Modified: `R/table_rows.R` (matrix output, `.compute_page_row_heights()`,
  span-aware `paginate_rows()`); `R/table_draw.R` (per-page row-h source,
  span-end matrix, span-aware clipping height in `.draw_cell_text()` calls,
  row-rule suppression predicate, renamed `cell_heights_in_mat` cache);
  `R/table_pagelist.R` (pass the matrix and `suppress_repeated_groups`).
- New tests: `tests/testthat/test-row_span.R` exercising the algorithm,
  pagination's free-row property, the orphan case, the per-page reset, and
  end-to-end rendering.

**Backward compatibility:** no exported API changes.  Existing tables
that did not use multi-line group labels render identically (same row
heights, same pagination).  Tables that did use them now render in less
vertical space, which may *increase* the number of rows on a page (and
correspondingly *decrease* the total page count).

---

## D-41: Column word-wrap module (issue #28)

**Decision:** Move all text-wrap logic for `tfl_table` into a dedicated
module file `R/wrap.R` and make the module default-on under
`wrap_cols = "auto"`.  Auto-detect promotes a column to wrap-eligible
when (and only when) its data or header contains a configured break
character.  A new `wrap_breaks()` argument lets the user configure which
characters count as breaks, with whitespace as the default and an
opt-in `keep_before` slot for characters like `-` or `/` that stay on
the left of the break.  Header labels are auto-wrapped using the same
mechanism as cell content.  A single row whose wrapped height exceeds
one page is now flagged via the same `overflow_action = "error" / "warn"`
switch added in D-39 — input that would silently overflow becomes an
explicit failure.

**User need (from issue #28):** "Any column that has spaces in any cell
of its contents should be considered for word wrapping ... start with
the widest column and consider it first then when it starts getting
shrunk too much start including the narrower columns."  Plus
"characters to wrap on should be an argument defaulting to removing any
whitespace in favor of wrapping but other breaking characters like `-`
should also be usable where the `-` is broken after."  Plus the
clarification that text-wrap and page-column-split are distinct
concepts that should be named and documented unambiguously.

**Algorithm — water-from-top.**  Replaces the prior "narrow the widest
column by the full excess" loop in `.apply_col_wrapping()`.  Per
wrap-eligible column we compute a *floor* equal to
`max(min_col_width, longest_unbreakable_token_in_column)`.  Each
iteration finds the maximal set of wrap-eligible columns above their
floor, computes the largest step that either (a) brings them down to
the next-widest competitor, (b) hits a floor, or (c) absorbs all
remaining excess, and applies that step uniformly to the whole set.
This keeps the widest columns balanced as they shrink rather than
crushing one column to its floor before considering the rest.
Deterministic, O(n²) in column count (n is the number of data
columns, typically << 30), terminates in at most `2n + 50` iterations
because each iteration either reduces excess by at least `eps`,
expands the active set, or saturates at a floor.

**Break-character spec.**  `wrap_breaks(drop, keep_before)` where:
- `drop` characters separate tokens *and* are consumed at the break
  point (whitespace).  Default: `c(" ", "\t")`.
- `keep_before` characters stay on the **left** of the break — the
  character ends a token, and the next character starts a new token.
  Useful for hyphenated terms (`-`) and path separators (`/`).
  Default: `character(0)`.

The two slots must be disjoint single-character vectors.  The
constructor returns a `wrap_breaks` S3 object so the validator can
distinguish a valid spec from a raw list.

**Auto-detect (`wrap_cols = "auto"`).**  In `resolve_col_specs()` a
column whose effective `wrap` is unspecified (NULL on the colspec, NA
on `wrap_cols = "auto"`) is marked `wrap = NA`.
`compute_col_widths()` resolves NA to TRUE/FALSE in a single pass: a
column is auto-eligible iff it is non-group AND its strings contain
any character from `breaks$drop` or `breaks$keep_before`.  Numeric
columns and single-token strings stay at FALSE because no narrowing
could break them.  Explicit `wrap = TRUE` / `wrap = FALSE` always wins.

**Header wrapping.**  `.measure_header_row_height()` and
`.draw_header_row()` accept the `wrap_breaks` spec and call a new
helper `.wrap_label_for_width()` to reflow labels onto multiple lines
*before* measuring (so row heights are correct) and *before* drawing
(so the rendered layout matches).  Headers wrap iff the column is
wrap-eligible AND has a resolved width — same condition as cell
wrapping.

**Row-overflow guard.**  `paginate_rows()` now accepts an
`overflow_action` argument and signals via `.overflow_signal()`.  When
the first (and only) row on a page has a committed height larger than
the page, the algorithm fires the guard.  The guard is suppressed for
the conservative bottom-continuation reserve case — i.e. when the row
would actually fit if no continuation marker were drawn after it —
because the existing pagination loop pessimistically reserves that
space whether or not it ends up being drawn.

**Naming clarification.**  The user pointed out that "wrap_cols" could
be misread as "split columns across pages".  In writetfl the names are
already disjoint (`wrap_cols` controls text-wrap *within* a column;
`allow_col_split` controls splitting columns *across* pages) but the
roxygen and the new vignette section now spell out the distinction
explicitly.  Both concepts are independent and freely composable.

**Alternatives considered and rejected:**
- *Per-column `wrap_breaks` on `tfl_colspec`* — useful for a future
  scenario where one column is a path and another is hyphenated, but
  not needed for the issue.  Easy follow-up because the table-level
  spec already threads through `tbl$wrap_breaks`.
- *base R `strwrap()` instead of a custom algorithm* — `strwrap()` is
  device-agnostic (counts characters, not rendered width) and does not
  accept a `gpar()`.  In a font-aware PDF context that's the wrong
  layer.
- *Wrap headers always (regardless of `cs$wrap`)* — surprising for
  users who explicitly set `wrap = FALSE` on a column to lock it.
  Tying header-wrap to cell-wrap keeps one knob.
- *Make `wrap_cols = TRUE` mean "auto-detect"* — collapses two distinct
  meanings.  Keeping `TRUE` as "all data cols, no detection" matches
  the prior semantics; `"auto"` is the new mode.

**Files touched:**
- New: `R/wrap.R` (the module — break spec, tokenizer, `.wrap_string`,
  auto-detect predicate, longest-token-floor measurement, water-from-top,
  header-label helper).
- Modified: `R/tfl_table.R` (new `wrap_breaks` arg, `wrap_cols = "auto"`
  default, `tfl_colspec(wrap = NA)` default, validation); `R/table_columns.R`
  (auto-detect resolution, switch to `.compute_wrapped_widths()`, removed
  `.apply_col_wrapping()`); `R/table_utils.R` (`.wrap_text()` is now a
  default-breaks shim, `.measure_header_row_height()` accepts a `breaks`
  arg); `R/table_draw.R` (drawDetails reads `tbl$wrap_breaks` and threads
  through; `.draw_header_row()` wraps labels); `R/table_rows.R`
  (`measure_row_heights_tbl()` accepts `breaks`, `paginate_rows()` adds
  the row-overflow guard with `overflow_action`); `R/table_pagelist.R`
  (passes `breaks` and `overflow_action` to the helpers).
- New tests: `tests/testthat/test-wrap.R` (47 unit tests for the
  module).  Extended `tests/testthat/test-tfl_table.R` with end-to-end
  cases including auto-detect, header wrapping, `keep_before`, and the
  row-overflow guard at both `error` and `warn` settings.
- New: `examples/wrap_demos.R` generating 14 demo PDFs and a README
  for hands-on review.
- New vignette section in `vignettes/v03-tfl_table_styling.Rmd`.

**Backward compatibility:** the `wrap_cols` default flips from `FALSE`
to `"auto"`, which can wrap previously-overflowing tables.  Per the
project owner's confirmation, no backward-compatibility constraint is
in force at this development stage.  Tables that already fit see no
behavioural change.

---

## D-42: Balance word-wrap with column-split (issue #35)

**Decision:** Reverse the order of the two algorithms that decide how a
wide `tfl_table` lays out: page-split the columns **first** using each
column's *minimum* survivable width as the capacity-planning input, then
water-fill each resulting page's columns locally within that page's
horizontal slack.  The pre-issue-#35 order (water-fill the whole table
down to one page width, then page-split using the post-wrap widths) is
preserved as `col_split_strategy = "wrap_first"` so the two orderings
can be empirically compared before removing the legacy one.

**User need (from issue #35):** the existing pipeline was producing
*every* page-column-split page with the *same* heavily-wrapped widths -
widths chosen to fit *all* columns on one page even when most ended up
on different pages.  Per-page water-fill gives each page columns sized
for that page's actual slack instead.

**Decision tree (in `.compute_col_widths_balanced()`):**

```
total_natural = sum(natural widths)
total_min     = sum(minimum widths)

if total_natural <= content_width:
  Case A  use natural widths; one page-group.
elif total_min <= content_width:
  Case B  one page-group; water-fill natural down to fit.
else:
  Case C  page-split using widths_min for capacity.  Per page,
            water-fill (natural -> page-slack) with group columns
            pinned at their min width so data columns absorb the slack.
            Reconcile per-page widths via .reconcile_page_widths()
            (group cols get the MIN across pages; data cols each
            appear on one page).
```

**Group column width rule (user's design call):** group columns repeat
on every page-column-split page.  Rather than letting each page choose
its group-column width independently (data-structure churn) or pinning
to the max width across pages (wastes per-page data slack), the package
pins group columns at their *minimum* width on every page.  Rationale:
group columns often carry multi-line labels that flow across rows via
the rowspan suppression behaviour added by issue #29, so they rarely
need full natural width.  Data columns benefit more from the slack.

**Row-overflow retry loop (step 5 of the issue):** after per-page widths
are decided, `paginate_rows()` measures cell heights and flags rows
whose wrapped height exceeds the page.  Under
`col_split_strategy = "balanced"` the orchestrator retries: it raises
the bottleneck column's minimum by 0.25 inches, runs the width pipeline
again, and re-paginates.  Up to `row_overflow_max_retries` iterations
(default `5L`; `0L` disables the loop).  After the cap, the final
`paginate_rows()` call goes through the existing `overflow_action`
path so the user-visible error/warn behaviour is unchanged.

For row-overflow recovery to work the *natural* width must also rise
with the retry floor.  Otherwise the Case-A branch (where
`sum(natural) <= content_width`) keeps the user's narrow fixed-width
setting and the cell still wraps to too many lines.  The implementation
bumps `widths_natural[j] <- max(widths_natural[j], floor_override[j])`
when overrides are applied.

**Helpers (`R/wrap.R`):**
- `.compute_col_min_widths()`  extracts the floor-measurement portion
  of `.compute_wrapped_widths()` so the balanced strategy can compute
  minimums once and reuse them in the decision tree.
- `.water_fill_to_budget()`  pure water-from-top loop taking
  pre-computed mins.  No scratch device; safe to call inside the
  per-page loop.
- `.reconcile_page_widths()`  flattens per-page width vectors into one
  per-column vector; group columns take the MIN across pages.

**`paginate_rows()` API change:** new `collect_overflows` parameter.
When `TRUE`, the function returns `list(pages, overflows)` instead of
signalling on row-overflow.  The retry loop in
`.tfl_table_to_pagelist_default()` uses this mode; the final
post-cap call uses `collect_overflows = FALSE` to fire the user's
`overflow_action`.

**`compute_col_widths()` dispatcher:** the function is now a thin
dispatcher on `tbl$col_split_strategy`.  Shared setup (Pass-1
auto-size, Pass-2 relative weights, Pass-3 auto-detect wrap
eligibility) lives in `.resolve_natural_widths()`.  Two strategy
functions handle the rest:
- `.compute_col_widths_wrap_first()` - legacy body preserved.
- `.compute_col_widths_balanced()` - new logic.

**Why keep both strategies in the same release?**  The user explicitly
asked for empirical before/after comparison.  The demo script renders
each scenario under both strategies so the difference is visible
side-by-side.  After evaluation the legacy path can be removed (one
function deletion + dispatch simplification) or kept as an escape hatch.

**Alternatives considered and rejected:**
- *Single-pass algorithm choosing widths and pages jointly* - global
  optimisation over `(page_assignment, per_page_widths)` is
  combinatorial in column count; for typical 5-30 column tables not
  worth the complexity vs. greedy split + per-page water-fill.
- *Per-page group-column width* - flattens per-page widths needed a
  more elaborate data structure with one width-per-(col, page).  Not
  worth the cognitive load when pinning at min keeps the structure
  flat and visually consistent.
- *Smarter row-overflow heuristic (move bottleneck column to its own
  page)* - the simple "raise the bottleneck's floor and re-split"
  approach already works for the cases the user described.  Out of
  scope; can be revisited if a test case shows the simple heuristic
  diverging.

**Files touched:**
- Modified: `R/table_columns.R` (dispatcher + two strategy functions +
  shared-setup helper + shared overflow-check helpers).
- Modified: `R/wrap.R` (three new helpers).
- Modified: `R/tfl_table.R` (two new args, validation, persistence).
- Modified: `R/table_rows.R` (`collect_overflows` param;
  bottleneck-col reporting in the row-overflow path).
- Modified: `R/table_pagelist.R` (retry loop wraps Step 4-6; per-iter
  helper for scratch-device lifecycle).
- New tests: `.water_fill_to_budget()`,
  `.reconcile_page_widths()`, balanced-vs-wrap_first end-to-end,
  retry-loop arg validation, `paginate_rows(collect_overflows = TRUE)`,
  `row_overflow_max_retries = 0L` disabling the loop.
- New demos: scenarios 15-18 in `examples/wrap_demos.R` (paired
  `_wrap_first.pdf` / `_balanced.pdf` PDFs).

**Backward compatibility:** the `col_split_strategy` default is
`"balanced"`, so multi-page tables under default settings will produce
different per-page column widths than before issue #35.  Per the
project owner's stance, no backward-compat constraint is in force.
Single-page tables (Case A or B) produce identical output under both
strategies (verified by a regression test).  `wrap_first` is preserved
as an opt-in for empirical comparison and as an escape hatch.

---

## D-43: Token-width memoization in word-wrap measurement

**Decision:** Add per-call string-width caches inside `.wrap_string()` and
`.column_min_token_width_in()`, and dedupe inputs in
`.measure_max_string_width()`.  The optional `cache` argument to
`.measure_text_width_in()` lets a caller share one memo across many
measurement calls.

**Context (profiling):** With the wrap module from issue #35 landed, profile
`tfl_table` / `export_tfl` on representative inputs and ship only
optimisations that show a real wall-clock win without obscuring the wrap
algorithms.  Harness lives at `examples/profile_writetfl.R`; a side-by-side
benchmark lives at `examples/bench_compare.R`.  Both are build-ignored.

Baseline self-time was dominated by `grid::grobWidth` and `grid::textGrob`
validation paths.  `Rprof(line.profiling = TRUE)` on the 18-demo
`wrap_demos.R` sweep showed `wrap.R#160` (the `grobWidth(textGrob(s, gp))`
call inside `.measure_text_width_in()`) accounting for **73.7%** of total
time, and `wrap.R#255` (per-token measurement inside
`.column_min_token_width_in()`) accounting for **34.7%**.  Inside
`.height_balance_widths_impl()` the existing per-(column, width) cache
already amortises height measurement; the remaining cost was text-width
re-measurement of repeated tokens and overlapping `cand` substrings inside
the greedy wrapper.

**Change:**
- `R/wrap.R` — `.measure_text_width_in()` gains an optional `cache` env
  parameter.  `.wrap_string()` creates one cache per call and passes it
  through to `.wrap_paragraph()`.  `.column_min_token_width_in()` creates
  one cache shared across all strings in the column.
- `R/table_utils.R` — `.measure_max_string_width()` runs `unique()` on its
  input vector before measuring.

The cache pattern mirrors the existing `memo` env in
`measure_row_heights_tbl()` (`R/table_rows.R:38-46`) and the per-(j, width)
cache in `.height_balance_widths_impl()` (`R/wrap.R:713`).  Each cache is
scoped to a single function call so lifetimes are obvious and no global
state leaks.

**Measured improvement** (medians from `examples/bench_compare.R`, 15
iterations for the core scenarios, 3 for `wrap_demos`):

| Scenario        | Before    | After     | Δ       |
|-----------------|-----------|-----------|---------|
| `core_small`    | 231 ms    | 198 ms    | ~14% ↓  |
| `core_wrap`     | 334 ms    | 225 ms    | ~33% ↓  |
| `core_paginate` | 583 ms    | 610 ms    | within noise (min-of-mins ~5% ↓) |
| `figure_multi`  | 342 ms    | 326 ms    | within noise |
| `wrap_demos`    | 9.88 s    | 3.43 s    | **~65% ↓** |

`wrap_demos` is the broadest signal because it exercises every wrap and
column-split code path in 18 different configurations.  `core_wrap` is the
targeted single-scenario probe (clinical fixture with
`wrap_balance = "height"`).  Both exceed the ≥10% bar by a large margin.
`core_paginate` runs `tfl_table(iris)` which exercises the Pass-1 natural
width measurement (where `.measure_max_string_width()` dedup helps) but
spends most of its time in row drawing; differences fall inside run-to-run
variance.

**Alternatives considered and rejected:**
- *Global LRU cache* — confuses lifetimes (when does a cache entry become
  stale?) and risks leaking state across unrelated calls; the per-call
  pattern already in the codebase is clearer.
- *Closure-based `make_width_cache(gp)`* — would bind the `gp` to the cache
  but requires changing every measurement call site from
  `.measure_text_width_in(s, gp)` to `measure(s)`.  Equal effect, more
  surface area than an optional `cache` arg.
- *Vectorising `.wrap_paragraph()` with width estimates* — the algorithm is
  intentionally a readable greedy walk; a width-estimate pre-screen would
  add a separate code path with subtle correctness conditions.  Profile
  did not justify the cost.
- *Pre-screening tokens by `nchar` in `.column_min_token_width_in()`* —
  width is not strictly monotonic in `nchar` once gpar changes are
  considered, so this requires a lower-bound argument that is easy to get
  wrong.  Memoization gets the same speedup without changing the algorithm.

**Out of scope / not done:**
- Touching `.compute_wrapped_widths()`, the water-fill loop, or
  `.height_balance_widths_impl()`'s search — these had no measurable
  bottleneck beyond what the existing per-(j, width) cache already handles.
- Rewriting `drawDetails.tfl_table_grob()` — its fallback branch at
  `R/table_draw.R:193-209` already short-circuits when the pipeline
  precomputed `row_heights_in`, which is the normal path.

**Files touched:**
- `R/wrap.R` — `.measure_text_width_in()`, `.wrap_string()`,
  `.wrap_paragraph()`, `.column_min_token_width_in()` (+~25 lines)
- `R/table_utils.R` — `.measure_max_string_width()` (+~5 lines)
- `examples/profile_writetfl.R` (new) — Rprof + profvis harness
- `examples/bench_compare.R` (new) — stash-friendly before/after timer
- `DESCRIPTION` — added `bench`, `profvis` to Suggests
- `.gitignore` — added `*.Rprof`, `examples/profvis_*.html`,
  `examples/profile_output/`

**Verification:**
- Full `devtools::test()` green before and after.
- `wrap_demos.R` produces identical page counts and PDF byte sizes
  (visual inspection of `21_*` family files).
- `examples/bench_compare.R` reproduces the table above.

---

## D-44: Hoist loop-invariant gpars and cache per-cell clip width in drawDetails

**Decision:** In `drawDetails.tfl_table_grob()`, precompute the per-column
cell gpar, the row-rule gpar, and the group-rule gpar once before the row
loop; pass a per-column width-measurement cache to `.draw_cell_text()` so
repeated cell text (numeric formats, category labels) doesn't re-pay the
`grobWidth(textGrob(...))` round-trip per row.

**Context (profiling, round 2):** With D-43 already shipped, the
`examples/profile_writetfl.R` re-run showed two remaining table-side hot
spots in `core_paginate` (`tfl_table(iris)`, 150 rows x 5 cols):

- `as.list` 1.91% self / **16.81% total** -- mostly from
  `.gp_with_lineheight()` being called inside the per-cell draw loop at
  `R/table_draw.R:363`.  Result depends only on `(gp_tbl, cs$is_group_col,
  lh)`, all invariant across rows.
- `grid.Call` / `validGP` / `set.gpar` together at ~30% total -- the
  remaining bulk fires from `.draw_cell_text()`'s clip-width measurement
  call at `R/table_draw.R:579`
  (`grid::grobWidth(grid::textGrob(text, gp = gp))`), which repeats for
  every cell even when the text is identical to one already measured in
  the same column.

**Change:**
- `R/table_draw.R` (`drawDetails.tfl_table_grob`):
  - Hoist `cell_gp_by_col <- lapply(page_cols, ...)` above the row loop;
    inner loop now reads `cell_gp_by_col[[j]]`.
  - Hoist `row_rule_gp` and `group_rule_gp` to single resolutions guarded
    by `isTRUE(tbl$row_rule)` / `isTRUE(tbl$group_rule)`.
  - Build a per-column width-measurement env
    (`clip_width_cache_by_col`) and pass it to `.draw_cell_text()`.
- `R/table_draw.R` (`.draw_cell_text`): new optional `width_cache`
  parameter, threaded into `.measure_text_width_in()`.  Comment links the
  cache to the D-43 pattern.

The clip-width measurement still happens, so the correctness story
(handling font-metric variance between the scratch PDF device and a
different rendering device) is preserved.  Only the duplication is gone.

**Measured improvement** (medians, 15 iterations; baseline = main at
4206e93 = D-43 shipped):

| Scenario        | Before    | After     | Δ                |
|-----------------|-----------|-----------|------------------|
| `core_small`    | 200 ms    | 190 ms    | ~5% (min: 16%)   |
| `core_wrap`     | 238 ms    | 235 ms    | within noise     |
| `core_paginate` | 592 ms    | 445 ms    | **~25% ↓**       |
| `figure_multi`  | 335 ms    | 352 ms    | within noise     |
| `wrap_demos`    | 3.34 s    | 2.78 s    | **~17% ↓**       |

`core_paginate` is the targeted scenario for draw-loop optimisations
(`tfl_table(iris)` spends most of its time in the row x col draw loop).
`wrap_demos` exercises the same draw path across all 18 demos so the
effect propagates.  `core_wrap` is unaffected because its bottleneck is
height-balance measurement (already optimal post-D-43).  `figure_multi`
never touches `drawDetails.tfl_table_grob`.

**Alternatives considered and rejected:**
- *Skipping the clip-width measurement entirely when the column had wrap*
  -- correct for that subset but adds a branch and only saves work in
  the wrap path.  The cache covers all paths with one mechanism.
- *Re-using the cell-height matrix's pre-computed widths from pagination*
  -- those widths were measured under the **scratch PDF** device.  The
  draw path's clip-width measurement intentionally re-measures on the
  **rendering** device to handle metric variance (e.g. knitr PNG vs PDF).
  Reusing pagination widths would silently regress that behaviour.
- *Direct mutation of gpar without `do.call(grid::gpar, ...)` in
  `.gp_with_lineheight()`* -- a tempting micro-optimisation, but
  hoisting the call site reduces invocations 150x and makes that
  micro-optimisation moot.

**Files touched:**
- `R/table_draw.R` -- one hoist block (~13 lines, with comment) before
  the row loop; two `rule_gp` substitutions inside the loop; new
  optional `width_cache` parameter on `.draw_cell_text()`.

**Verification:**
- Full `devtools::test()` green before and after.
- `examples/bench_compare.R` reproduces the table above.

---

## D-45: Fast-path cell drawing, position-based tokenizer, and per-page formatting

**Decision:** Three independent, profile-driven changes layered on top of
D-43/D-44:

1. **Fast path in `.draw_cell_text()`** — when the measured text width
   plus horizontal padding is no greater than the column width, draw
   directly in the parent viewport instead of pushing a per-cell
   clipping viewport.  The clip viewport (which created+pushed+popped
   per cell) is still used in the slow path, where text might bleed.
2. **Drop redundant `convertUnit` calls in `.draw_cell_text()`'s clip
   path** — the clip viewport is constructed with explicit
   `unit(clip_w, "inches")` / `unit(row_h, "inches")` dimensions, so
   the post-push `vp_w2 <- .width_in(unit(1, "npc"))` /
   `vp_h2 <- .height_in(unit(1, "npc"))` calls were re-measuring known
   values.  Replaced with the literals.
3. **Position-based tokenizer in `.tokenize_for_wrap()`** — replaced the
   per-token `paste(cur_buf[seq_len(cur_n)], collapse = "")` with
   `substr(s, cur_start, cur_end)`.  One C call per token instead of
   `n` element accumulations + `paste`.
4. **Per-page formatting hoist in `drawDetails`** — replaced per-cell
   `.fmt_cell(data[[cs$col]][i], na_str)` with a single
   `.fmt_cell_vec(data[[cs$col]][rows], na_str)` per column built before
   the row loop.

**Context (profiling, round 3):**  Post-D-44, the `core_paginate`
Rprof showed `table_draw.R:403` (the `.draw_cell_text()` call site)
accumulating **73% of total time**.  Drilling into `.draw_cell_text()`:

| Line | Self self.pct | Total total.pct | What |
|------|--------------|-----------------|------|
| 597 (measure) | 0.73% | 13.76% | text-width measurement (cached, but still per cell) |
| 603 (vp_clip) | 1.17% | 13.03% | viewport creation (4 `grid::unit()` + `viewport()`) |
| 611 (pushViewport) | — | — | pushing the clip vp |
| 625 (grid.text)   | 0.29% | 29.14% | the actual text draw |
| 633 (popViewport) | 0.15% | 6.44% | popping |

The viewport push/pop pair (~20% of total) is only meaningful when text
overflows the column.  For all-numeric tables (iris) and post-wrap
cells, the text always fits and the clip is redundant.

**Measured improvement** (medians, 15 iterations per core scenario, 3
for `wrap_demos`, 5 independent runs averaged; baseline = main + D-43 +
D-44 at `7c9484c`):

| Scenario        | Before    | After     | Δ                       |
|-----------------|-----------|-----------|-------------------------|
| `core_small`    | 146 ms    | 111 ms    | **~24% ↓**              |
| `core_wrap`     | 206 ms    | 209 ms    | within run-to-run noise |
| `core_paginate` | 397 ms    | 270 ms    | **~32% ↓**              |
| `figure_multi`  | 318 ms    | 330 ms    | within noise            |
| `wrap_demos`    | 2.97 s    | 2.80 s    | **~6% ↓**               |

`core_paginate` (the iris-heavy draw scenario) and `core_small`
(short table going through the same draw loop) get the biggest gains.
`wrap_demos` had high run-to-run variance with only n=3 iterations;
averaged across 5 independent runs it shows a steady ~6% reduction.
`core_wrap` is unchanged because its bottleneck is height-balance
measurement, not cell drawing.  `figure_multi` doesn't touch
`drawDetails.tfl_table_grob`.

**Alternatives considered and rejected:**
- *Regex-based vectorized tokenizer* — `regmatches`/`strsplit`-driven
  reimplementation would shave more time but the algorithm has subtle
  drop-vs-keep_before semantics (multiple consecutive drops collapse to
  one lead, keep_before chars stay with the preceding token).  The
  position-based change keeps the existing algorithm verbatim and
  preserves the comment-level explanation.  Faster vectorization was
  not worth the risk-of-regression.
- *Pre-computed parent-viewport coordinates passed into
  `.draw_cell_text()`* — would push more work into the drawDetails
  body.  The current shape (compute once inside `.draw_cell_text()`) is
  shorter and the per-call overhead is now tiny.
- *Skipping the text-width measurement entirely when `nchar(text)` is
  small enough* — would require a font-aware upper bound on per-char
  width; fragile across font sizes and families.  The cached
  measurement is already cheap on cache hit.

**Files touched:**
- `R/table_draw.R`:
  - `drawDetails.tfl_table_grob`: hoisted `cell_strs_by_col` (vectorised
    formatting), and the existing hoists from D-44 are unchanged.
  - `.draw_cell_text`: added fast/slow branch on `needed <= col_width_in`,
    removed the two post-push `convertUnit` calls in the slow path.
- `R/wrap.R`:
  - `.tokenize_for_wrap`: track `cur_start`/`cur_end` positions and
    emit text via `substr()` instead of accumulating + pasting.

**Verification:**
- Full `devtools::test()` green before and after.
- `examples/bench_compare.R` reproduces the table above (averaging over
  multiple runs is needed for `wrap_demos`'s lower-iteration sample).

---

## D-46: Cross-page clip-width cache shared across all pages of one tfl_table

**Decision:** Construct one list of clip-width cache envs (one per column
in `resolved_cols`) at the top of `tfl_table_to_pagelist()` and pass it
into every `build_table_grob()` call.  Every page-grob built for the
same table holds a reference to the same env list, so
`drawDetails.tfl_table_grob()` can reuse cached measurements across all
row-page x col-group combinations.

**Context:** D-44 introduced a per-page clip-width cache.  Profiling and
focused benchmarking showed that for tables spanning many pages, the
same cell text typically appears on every page (numeric formats,
visit labels, category codes), so each page was re-measuring the same
strings.  A single env shared across pages eliminates that
inter-page duplication while preserving the intra-page hits D-44
already provided.

**Change:**
- `R/table_pagelist.R` -- inside `tfl_table_to_pagelist()` (and the
  table1/flextable equivalents that call `build_table_grob` similarly),
  `clip_width_caches <- lapply(seq_along(resolved_cols), function(k)
  new.env(...))` is built once, then threaded to every
  `build_table_grob()` invocation.
- `R/table_draw.R` -- `build_table_grob()` gains a `clip_width_caches`
  argument stored as a grob slot.  `drawDetails.tfl_table_grob()` now
  prefers `x$clip_width_caches[x$col_group_idx]` over creating fresh
  per-page envs, falling back to the old behaviour when the slot is
  absent (e.g. for grobs built outside the normal pipeline).

The cache is keyed by column index into `resolved_cols` (stable across
col-group splits), not by the local `j` index in `page_cols` (which
re-numbers per col-group).

**Measured improvement** (medians, 30 iterations; baseline = round-3
HEAD at `7fcf208` = D-45 shipped):

| Scenario        | Before    | After     | Δ           |
|-----------------|-----------|-----------|-------------|
| `iris5p` (150 rows / 5 pages) | 264 ms | 258 ms | ~2% (modest) |
| `big_df` (500 rows / ~17 pages, 4 cols incl. repeating categoricals) | 1560 ms | 1330 ms | **~15% ↓** |

The gain scales with page count and amount of inter-page duplication.
Short single-page tables see negligible benefit (the per-page cache
already caught everything).  Realistic multi-page clinical listings
hit the design sweet spot.

**Alternatives considered and rejected:**
- *Cache spanning pagination (scratch device) + drawing (render device)*
  -- the documented re-measurement in `.draw_cell_text()` exists
  because font metrics can legitimately differ between the scratch
  PDF and the render device (e.g. knitr PNG vs PDF for preview mode).
  A cross-device cache would risk inaccurate placement, which the
  project owner explicitly excluded.
- *Consolidated (width, height) cache in pagination* -- would save
  ~half the gpar-validation overhead in `.measure_max_string_width()`
  + `.memo_str_height()` by sharing one textGrob's measurements
  between Pass 1 (widths) and Pass 2 (heights).  Independent of this
  change; worth pursuing only if benchmarks justify the threading
  cost.  Deferred.
- *Package-level env keyed by tbl-object identity* -- zero plumbing,
  but a global mutable env is harder to reason about (parallelism,
  leaked entries).  The explicit list-threaded approach is clearer.

**Files touched:**
- `R/table_pagelist.R` -- one new `clip_width_caches` construction
  block in `.tfl_table_to_pagelist_default()` and the corresponding
  pass-through in the `build_table_grob()` call.
- `R/table_draw.R` -- `build_table_grob()` accepts and stores the
  cache; `drawDetails.tfl_table_grob()` reads it via
  `x$clip_width_caches`.

**Verification:**
- Full `devtools::test()` green.
- `examples/bench_focused.R` (n=30) reproduces the `iris5p` /
  `big_df` table above.

---

## D-47: Consolidated width+height text-dimension cache during pagination

**Decision:** Replace the two separate per-call height memos with a single
`(gp_key, string) -> list(w, h)` cache that lives for one
`.tfl_table_to_pagelist_default()` call.  Every textGrob built for
measurement during pagination populates both dimensions; subsequent
lookups for either dimension reuse the existing entry.

**Context:** Profiling after D-46 showed that pagination still constructed
two textGrobs for every unique cell string -- one in
`.measure_max_string_width()` (Pass 1, widths) and one in
`measure_row_heights_tbl()` (Pass 2, heights).  Each construction re-runs
grid's `validGP` / `set.gpar` chain, the dominant per-call cost.  Pass 1
and Pass 2 use the same gpar for matching column categories
(`data_row`, `group_col`, `header_row`), so the same (gp, string) shows
up twice in pagination work.

**Change:**
- `R/table_utils.R` -- new `.measure_text_dims_in(s, gp, gp_key, cache)`
  helper that builds the textGrob once, reads both dimensions, and
  caches the pair.  Existing `.measure_max_string_width()` and
  `.measure_header_row_height()` now accept an optional cache and
  delegate per-string measurement to the helper when provided.
- `R/table_rows.R` -- `measure_row_heights_tbl()` accepts a cache and
  replaces its inline `.memo_str_height()` closure with the same helper.
- `R/table_columns.R` -- `compute_col_widths()` and `.resolve_natural_widths()`
  thread a `cache` argument; the natural-width pass builds the
  appropriate structural `gp_key` for cell-vs-header gpars and passes
  it down.
- `R/table_pagelist.R` -- `.tfl_table_to_pagelist_default()` creates one
  `text_dim_cache <- new.env(hash = TRUE, parent = emptyenv())` at the
  top and passes it to `compute_col_widths()`,
  `.measure_header_row_height()`, and `measure_row_heights_tbl()`.

The `gp_key` namespace matches what `measure_row_heights_tbl()` already
used internally (e.g. `"data_row_lh1.2"`, `"group_col_lh1.2"`,
`"header_row_lh1.2"`).  All callers that share a category resolve to the
same key, so width-then-height (Pass 1 -> Pass 2) on the same `(category,
string)` is a cache hit.

**Why crossing scratch-device boundaries is safe here:** the multiple
PDF scratch devices opened during pagination
(`.resolve_natural_widths`, `.run_pagination_iter`) all use identical
`(pg_width, pg_height)` settings, identical fonts, and identical R
session state.  PDF device font metrics are deterministic given those
inputs, so values measured on one scratch device are equal to what
the next scratch device would produce.  The cache does NOT cross into
the render-device drawing phase -- that boundary still goes through
`.draw_cell_text()`'s separate re-measurement (D-44/D-46 territory).

**Measured improvement** (n=30 iterations, baseline = round-3 HEAD at
`61bd26a` = D-46 shipped; min-of-mins across 3 independent runs to
suppress system-load noise):

| Scenario | Before (min) | After (min) | Δ          |
|----------|--------------|-------------|------------|
| `iris5p` (150 rows / 5 pages) | 329 ms | 255 ms | **~22% ↓** |
| `big_df` (500 rows / ~17 pages, 4 cols) | 1.45 s | 1.36 s | ~6% ↓ |

`iris5p` is the targeted scenario for pagination-side optimisation:
relatively small data, many measurement-heavy passes.  `big_df` is
dominated by drawing rather than measurement (D-44/D-46 territory), so
the pagination cache helps less in relative terms.

**Alternatives considered and rejected:**
- *Caching width and height under separate keys* -- requires the cache
  consumer to ask for the right dimension and stores two entries per
  unique string.  Consolidated `(w, h)` tuple is one entry, one
  textGrob construction, and any pass that has either dim gets the
  other for free.
- *Hashing the full gpar object as the cache key* -- gpars carry many
  fields; per-lookup hashing costs more than the structural-key
  approach the codebase already uses internally.  Callers pre-compute
  `gp_key` once per gpar.
- *Threading the cache further down into `.compute_col_min_widths()`
  and `.height_balance_widths_impl()`* -- those have their own
  per-call caches keyed differently (per-token, per-(j, width)).
  Bringing them into the unified cache would require harmonising key
  schemes and is left for a follow-up if profile data justifies it.

**Files touched:**
- `R/table_utils.R` -- new `.measure_text_dims_in()` helper; cache-aware
  `.measure_max_string_width()` and `.measure_header_row_height()`.
- `R/table_rows.R` -- cache-aware `measure_row_heights_tbl()`.
- `R/table_columns.R` -- cache-aware `compute_col_widths()` and
  `.resolve_natural_widths()`.
- `R/table_pagelist.R` -- cache construction in
  `.tfl_table_to_pagelist_default()` and threading into the three
  pagination measurement entry points.

**Verification:**
- Full `devtools::test()` green.
- `examples/bench_focused.R` (n=30) reproduces the table above.

---

## D-48: Single device per export_tfl() + cross-phase text-dim cache

**Decision:** Open exactly one PDF device per `export_tfl()` call.
Pagination measurements and the per-page draw loop both run on that
device.  The `text_dim_cache` populated during pagination is attached
to every `tfl_table_grob` and reused by `.draw_cell_text()` so the
per-cell width re-measurement at draw time becomes a single env
lookup.

**Context:** D-46/D-47 brought the pagination cache inside one
process-wide env, but the cache documented its boundary as the
render-device transition: `.draw_cell_text()` always re-measured
because the scratch PDF used for pagination and the user-visible
render device could differ in font metrics (e.g. PNG in knitr).

In practice the package's "render device" is *always* a PDF -- either
`pdf(file)` opened by `.export_tfl_pages()` in normal mode, or the
user's own device in preview mode.  Phase-0 profiling showed
`.draw_cell_text`'s re-measure consuming **8.87 %** of total time in
`core_paginate` -- the line was the single largest target.  Eight
helpers across `R/` opened their own scratch `pdf()` devices for
font-metric resolution, each costing ~5 ms; while never individually
hot, collectively they added measurable overhead and complicated the
device-lifecycle invariant.

**Change:**

1. New helpers in `R/export_tfl.R`:
   - `.open_metric_device(file, pg_width, pg_height, preview, envir)`
     -- opens `pdf(file)` in normal mode or `pdf(NULL, ...)` in
     preview mode, and registers `on.exit({...; dev.off()}, add =
     TRUE)` on the CALLER's frame so a mid-execution error still
     closes the device.
   - `.close_metric_device(md)` -- idempotent close; preview-mode
     callers invoke it explicitly after pagination so the user's
     pre-existing device is restored for drawing.

2. Every `export_tfl` S3 method calls `.open_metric_device()` BEFORE
   pagination:
   - `.default`, `.tfl_table`, `.list`, `.ggtibble`, `.gt_tbl`,
     `.VTableTree`, `.flextable`, `.table1`.
   - `.export_tfl_pages()` gains a `pdf_already_open = FALSE`
     parameter; the dispatchers pass `TRUE` so it skips its own
     `pdf(file)` / `dev.off()`.

3. Eight scratch-device opens deleted from `R/`:
   - `compute_table_content_area()`, `.run_pagination_iter()` in
     `R/table_pagelist.R`
   - `.resolve_natural_widths()` in `R/table_columns.R`
   - `.compute_col_min_widths()`, `.compute_wrapped_widths()`,
     `.height_balance_widths()` in `R/wrap.R`
   - `.gt_grob_height()` in `R/gt.R`
   - `.rtables_lpp_cpp()` in `R/rtables.R`
   Each helper now relies on the upstream metric device.  Outer-
   viewport push/pop preserved (still needed for inch resolution
   against the post-margin content area).

4. Cross-phase cache plumbing in `R/table_pagelist.R` and
   `R/export_tfl.R`:
   - `tfl_table_to_pagelist()` accepts an optional `text_dim_cache`
     parameter; when supplied, that env is reused instead of being
     allocated locally and discarded.
   - `export_tfl.tfl_table()` allocates `pagination_cache`, threads
     it through pagination, then attaches it to every
     `tfl_table_grob` in PDF mode (`drawing_cache <- pagination_cache`).
     Preview mode attaches a fresh **empty** env instead, so
     drawing's lookups all miss and the function falls through to
     per-cell measurement on the user's render device -- preserving
     today's preview behaviour exactly.

5. Cache consumption in `R/table_draw.R`:
   - `drawDetails.tfl_table_grob()` extracts `x$text_dim_cache` and
     computes `gp_key_by_col` matching pagination's
     ("data_row_lh<lh>", "group_col_lh<lh>") namespace.
   - `.draw_cell_text()` gains `text_dim_cache` and `gp_key`
     arguments.  Width lookup order: text_dim_cache hit ->
     per-column `width_cache` (D-46) -> fresh measurement.
   - `.draw_header_row()` uses the matching `"header_row_lh<lh>"` key.

6. Safety guard in `.measure_text_dims_in()`:
   `if (grDevices::dev.cur() == 1L) rlang::abort(...)` on the slow
   path catches future regressions where a caller forgets to open
   the metric device.

**Why crossing the render-device boundary is safe here:** the
single device opened by `.open_metric_device()` IS the render
device in normal mode (`pdf(file)`).  Pagination and drawing
measure against identical font metrics by construction -- no
inference required.  In preview mode the cache is empty and the
boundary still holds via per-cell re-measurement.

**Measured impact** (n=30 per scenario; min-of-mins across 3 runs,
b196ca3 vs HEAD on the same machine):

| Scenario       | Baseline | After   | Δ        |
|----------------|----------|---------|----------|
| `iris5p`       | 213 ms   | 200 ms  | **−6 %** |
| `big_df`       | 1.25 s   | 1.10 s  | **−12 %**|
| `wrap_heavy`   | 2.24 s   | 1.94 s  | **−13 %**|
| `preview_iris` | 194 ms   | 166 ms  | **−14 %**|
| `figure_multi` | 619 ms   | 605 ms  | −2 %     |

`figure_multi` is within variance, as expected: the ggplot pipeline
neither populates nor reads the cache.  `preview_iris` benefits
from scratch-device elimination even though its cache is empty by
design.

Profile signal (Rprof @ 0.01s, core_paginate):

| Site                                | Baseline | After  |
|-------------------------------------|----------|--------|
| `.measure_text_width_in` inside `.draw_cell_text` | 8.87 % total | 0.5 % total |

A 17× drop on the line that motivated the refactor.

**Alternatives considered and rejected:**

- *Unify all four caches (D-46 clip_width_caches, D-47 text_dim_cache,
  wrap.R width_cache, wrap.R tokenize cache) into one helper.*  An
  early prototype routed `.measure_text_width_in()` through
  `.measure_text_dims_in()` for a single `(w, h)` cache contract.  It
  cost 20-30 % on `wrap_heavy`, `big_df`, and `preview_iris` because
  the wrap module's inner loop calls .measure_text_width_in() many
  times per cell and the extra function call + list-wrapping on
  cache hits dominated.  Documented in the
  `.measure_text_width_in()` source comment; the two helpers stay
  separate because the inner loop cannot afford the indirection.
- *Use the user's device for pagination in preview mode (true single
  device).*  Would make preview pagination decisions vary with the
  user's render device (PNG vs screen vs PDF).  Today's pagination
  is device-agnostic relative to user device; preserving that
  contract was a user-stated constraint.  Preview mode therefore
  opens a transient `pdf(NULL)` for pagination, closes it before
  drawing.

- *Drop `.export_tfl_pages`'s legacy `pdf_already_open = FALSE`
  path.*  Defensible cleanup (no caller in package passes FALSE
  after Phase 1c), but kept defensive in case external code
  invokes `.export_tfl_pages()` directly.

**Files touched:**
- `R/export_tfl.R` -- `.open_metric_device()`, `.close_metric_device()`,
  wired into `.default`, `.tfl_table`, `.list`;
  `.export_tfl_pages()` gains `pdf_already_open` parameter.
- `R/ggtibble.R`, `R/gt.R`, `R/rtables.R`, `R/flextable.R`,
  `R/table1.R` -- wired in their respective S3 methods.
- `R/table_pagelist.R` -- `text_dim_cache` plumbing through
  `tfl_table_to_pagelist`, `.tfl_table_to_pagelist_default`,
  `.tfl_table_to_pagelist_sub_tfl`; `compute_table_content_area`
  and `.run_pagination_iter` drop their scratch devices.
- `R/table_columns.R` -- `.resolve_natural_widths` drops its
  scratch device.
- `R/wrap.R` -- three helpers drop their scratch devices; the
  `.measure_text_width_in` comment documents why it stays separate
  from `.measure_text_dims_in`.
- `R/table_draw.R` -- `.draw_cell_text` and `.draw_header_row`
  consume the cache; `drawDetails.tfl_table_grob` extracts it from
  the grob.
- `R/table_utils.R` -- `.measure_text_dims_in` accepts `NULL`
  gp_key; safety guard for missing device.
- `R/gt.R`, `R/rtables.R` -- scratch device opens removed.
- `tests/testthat/test-export_tfl.R` -- 8 new tests (4 helper tests
  for `.open_metric_device` / `.close_metric_device`, plus
  device-count, font-metric equality, safety-guard fires, cache
  shape).
- `examples/bench_focused.R` -- added `wrap_heavy`, `preview_iris`,
  `figure_multi` scenarios.
- `design/perf-baseline-notes.md` -- new working note with the
  Phase-0 and Phase-5 numbers and the per-phase outcome table.

**Verification:**
- Full `devtools::test()` -- 587 passing, 0 failed.
- `examples/bench_focused.R` (n=30, 3 runs) reproduces the table
  above.
- `grep -n "grDevices::pdf(" R/` shows exactly three occurrences,
  all in `R/export_tfl.R` (the `.open_metric_device` normal/preview
  paths + the defensive legacy fallback in `.export_tfl_pages`).

## D-49: Preserve leading whitespace in wrapped text + tab expansion

**Decision:** The word-wrap module preserves a line's leading whitespace
as a *hanging indent* (the prefix is re-attached to every wrapped line of
the paragraph, and its width is charged against the line so wrapping
accounts for it).  Tab characters are expanded to spaces before
wrapping: a *leading* (indentation) tab becomes `tab_indent_spaces`
spaces (default 2), an *in-line* tab becomes `tab_infix_spaces` spaces
(default 1).  The two tab counts are advanced knobs surfaced only via
`...` on `export_tfl()` / `export_tfl_page()`; they are not added to the
main function signatures.  The counts are *defined* (with their defaults)
in exactly one place — `.convert_tabs()` — and every function above it
passes `...` straight through, so there is no per-layer default to keep
in sync.  Their documentation is shared via roxygen's
`@inheritDotParams .convert_tabs tab_indent_spaces tab_infix_spaces`.

**Context:** The tokenizer (`.tokenize_for_wrap()`) treats a run of
`drop` characters as a between-token separator, and `.wrap_paragraph()`
drops the first token's separator.  A cell or content string like
`"   Indented label"` therefore lost its leading spaces entirely, so the
common clinical convention of indenting sub-category labels with spaces
silently collapsed.  Empirically confirmed: `.wrap_string("   Indented
label", ...)` returned `"Indented label"`, while `grid::textGrob()`
itself *does* render leading spaces (a 3-space prefix measures ~0.139 in)
— so the loss was purely in the wrap module, not the device.

Separately, the PDF device cannot render the tab glyph (0x09): it draws
nothing and warns "font width unknown for character 0x09".  A tab in cell
or content text would therefore vanish (and emit warnings during both
measurement and drawing).

**Change:**

1. `R/wrap.R`:
   - `.leading_drop_run(s, drop_chars)` — returns the maximal leading run
     of `drop` characters (fast-pathed when the first char isn't one).
   - `.convert_tabs(s, ..., tab_indent_spaces = 2L, tab_infix_spaces = 1L)`
     — expands leading vs. in-line tabs to spaces; tab-free strings
     short-circuit.  This is the *only* function that defines the two
     counts and their defaults; the named args sit after `...` so they are
     matched by name, and `...` absorbs any unrelated pass-through args
     (e.g. `overlap_warn_mm`) that arrive via the forwarding chain.
     Roxygen-documented so its params can be reused via `@inheritDotParams`.
   - `.wrap_paragraph()` converts tabs (forwarding `...` to
     `.convert_tabs()`), captures the leading run, wraps the body against
     the width reduced by the indent, and re-attaches the prefix to every
     wrapped line.  Whitespace-only paragraphs return the (converted)
     prefix rather than `""`.
   - `.column_min_token_width_in()` adds `indent + widest token` to the
     per-column floor (so an indented wrapped cell cannot clip when the
     column is narrowed) and converts tabs first.  It too takes `...` and
     forwards it to `.convert_tabs(p, ...)`, so *every* `.convert_tabs()`
     call site receives the same knobs and the floor can never disagree
     with the drawn text under a non-default tab width.
   - `.wrap_string()` takes `...` and forwards it to `.wrap_paragraph()`;
     no tab args of its own.

2. Pure `...` forwarding for the page-level character / caption / footnote
   paths (table cells and headers use the `.convert_tabs()` defaults):
   - `.wrap_text()` (`R/table_utils.R`), `wrap_normalized_text()`
     (`R/normalize.R`), and `draw_content()` (`R/draw.R`) gain `...` and
     forward it down — no explicit tab args, no per-layer defaults.
   - `export_tfl_page()` does **not** read or validate the tab counts; it
     forwards `...` (after reading `overlap_warn_mm` for its own use) to
     the caption/footnote wrap and `draw_content()`.  `export_tfl()`
     already forwards `...`, so the knobs reach the page function
     unchanged.
   - Documentation is kept DRY with `@inheritDotParams .convert_tabs
     tab_indent_spaces tab_infix_spaces` on `.wrap_string()`,
     `.column_min_token_width_in()`, `wrap_normalized_text()`,
     `draw_content()`, and `export_tfl_page()`.  `export_tfl_page()`'s own
     `overlap_warn_mm` dot-arg is documented via a second
     `@inheritDotParams check_overlap overlap_warn_mm` (roxygen merges
     multiple `@inheritDotParams` into the one `...` item), so no `...`
     argument is described by hand in `@param`/`@details`.

**Alternatives considered:**

- *Indent on the first line only* (the initial implementation): rejected
  after review — a hanging indent reads correctly when indented content
  wraps, and matches the "every wrapped line stays indented" expectation.
- *Explicit `tab_indent_spaces` / `tab_infix_spaces` params with defaults
  on every function in the chain* (the first implementation of this
  decision): rejected — it duplicated the defaults and the doc strings at
  each layer.  Defining them once in `.convert_tabs()` and forwarding
  `...` everywhere above is DRY and keeps the defaults in a single place.
- *Carrying tab config on the `wrap_breaks` object*: rejected; tab
  expansion is orthogonal to break-character policy, and the request was
  explicitly to surface it via `...` rather than a documented argument.
- *Making `tab_infix_spaces` configurable for table cells via a new
  `tfl_table()` `...`*: deferred.  In-line whitespace runs collapse to a
  single break inside `.wrap_string()` anyway (pre-existing behaviour),
  so `tab_infix_spaces > 1` is not visible through the wrap; table cells
  use the defaults and an explicit space count is available by typing
  literal spaces.

**Tests:** `tests/testthat/test-wrap.R` — `.leading_drop_run()`,
`.convert_tabs()`, leading-space preservation (exact count, hanging
indent across wraps, whitespace-only, per-paragraph), tab expansion and
custom counts.  `tests/testthat/test-normalize.R` — tab knobs forwarded
through `wrap_normalized_text()`.  `tests/testthat/test-export_tfl_page.R`
— tabbed character content renders without the device warning and the
`...` knobs (mixed with `overlap_warn_mm`) flow through without error.

**Verification:** full `devtools::test()` passing; manual repro confirms
3 leading spaces survive (`"   Indented label"` round-trips) and a
`\t`-indented export produces no `0x09` warning.

## D-50: Run testthat in parallel

**Decision:** Enable parallel test execution via
`Config/testthat/parallel: true` in `DESCRIPTION`, with
`Config/testthat/start-first: tfl_table, gt, integration, table1,
flextable, rtables` to launch the slowest files first.

**Context:** The suite has 22 test files and takes ~184 s sequentially on
an 8-core machine.  Edition 3 (already set) supports running each file in
its own worker subprocess.  The connector / rendering files (`tfl_table`,
`gt`, `integration`, `table1`, `flextable`, `rtables`) dominate runtime.

**Change:**

1. `DESCRIPTION` — add `Config/testthat/parallel: true` and
   `Config/testthat/start-first: ...`.
2. `tests/testthat/test-export_tfl.R` — the
   `.measure_text_dims_in fails fast without an active device` test
   depended on the null-device state (`dev.cur() == 1L`).  Sequentially it
   happened to hold; under parallel a worker runs several files in one
   process, so a graphics device left open by an earlier file in that
   worker was still current and the guard did not fire.  The test now
   closes any open device first
   (`while (grDevices::dev.cur() > 1L) grDevices::dev.off()`) so it
   establishes its own precondition and is order-independent.

**Measured impact** (8 cores): ~184 s sequential -> ~115 s parallel
(~35-40 % faster).  All 22 files run; 608 test blocks; 0 fail / 0 skip /
0 warn; `R CMD check --as-cran` clean.

**Note on test hygiene:** with parallel execution a test must not rely on
ambient global state left by another file (most relevantly the graphics
device stack).  See TESTING.md.

---

## D-51: Suppress the leading blank page for tabular inputs

**Decision:** `export_tfl_page()` gains a `newpage = TRUE` argument.
`export_tfl()` sets `newpage = FALSE` for the **first** page in normal
(PDF) mode; every later page keeps the default `TRUE`.  When `FALSE`,
`export_tfl_page()` skips `grid.newpage()` and instead resets the
viewport stack with `grid::upViewport(0)`.

**Context:** Under D-48 a single metric device covers both pagination
measurement and drawing.  Pagination for tabular inputs (`tfl_table`,
`gt`, `rtables`, `flextable`, `table1`) calls `convertHeight()` /
`grobHeight()` etc. to size content; on a `pdf()` device the very first
such metric query **opens page 1** (empirically confirmed — even a bare
`convertHeight()` with no `pushViewport()` does this).  The draw loop then
began every page, including the first, with `grid.newpage()`, which
advanced past that already-open blank page and emitted a spurious leading
blank page.  Figures never measure, so their device was pristine and the
first `grid.newpage()` was a no-op — which is why the blank page appeared
only for tables, not figures.

**Why this fix:** The pdf device has no API to "un-open" the blank page
1, so the first drawn page must *reuse* it rather than advance past it.
Skipping `grid.newpage()` on the first page does exactly that.
`upViewport(0)` supplies the viewport-stack reset that `grid.newpage()`
would otherwise provide, guarding against any imbalance left by
measurement.  The change is uniform: for figures the first-page device is
fresh and `grid.draw()` lazily opens page 1, so skipping the newpage
still yields the correct single page.

**Alternatives rejected:**
- *Only skip the newpage on measuring (tabular) paths.* More branching,
  and the uniform skip is provably correct for figures too.
- *Separate measurement and drawing devices.* Reverses D-48 and
  reintroduces re-measurement plus the 64-device pressure D-48 removed.
- *Reset the pdf page counter after pagination.* No such API exists.

**Change:**

1. `R/export_tfl_page.R` — add `newpage = TRUE`; branch on it
   (`grid.newpage()` vs `grid::upViewport(0)`).
2. `R/export_tfl.R` — `.export_tfl_pages()` normal-mode loop sets
   `page_args$newpage <- (i != 1L)`.  Preview mode is unchanged (each
   page still `grid.newpage()`s on the user's device).

**Tests:** `tests/testthat/test-integration.R` gains a `count_pdf_pages()`
raw-byte helper (no `pdftools` dependency) and regression tests asserting
a single-page `tfl_table` yields exactly one PDF page, that a figure and a
table yield the same page count, and that multi-page tables carry no
leading blank.

---

## D-52: A single `NA` is treated as `NULL`/absent for annotation & toggle args

**Decision:** In `export_tfl_page()`, a length-1 atomic `NA` (of any type)
supplied for an annotation or presence-toggle argument is treated exactly like
`NULL` (the "absent" state). This covers `caption`, `footnote`,
`header_left/center/right`, `footer_left/center/right` (section element
absent), `page_i` (no `"Page <i>: "` error prefix), and `header_rule` /
`footer_rule` (no rule, i.e. `FALSE`). Implemented once via the shared
predicate `.is_single_na()` in `R/normalize.R`, consumed by `normalize_text()`,
`normalize_rule()`, and the `page_i` coercion in `export_tfl_page()`. Because
the annotation arguments flow through `normalize_text()` after the `x[[key]]`
override merge, this also lets a per-page `x$caption = NA` blank an
otherwise-global caption.

**Motivation:** Page lists are frequently built from data frames (one row per
page). A column feeding an annotation naturally carries `NA` for pages where
the value is not applicable; without this, `NA` renders as the literal text
`"NA"` or errors. Treating a lone `NA` as absent makes data-driven
construction ergonomic.

**Scope — arguments deliberately left to fail loudly on `NA`:**
- `padding`, `margins`, `min_content_height` — `unit` objects; an `NA` is a
  malformed value, not an "unset" signal, and `checkmate::assert_class()`
  rejects it.
- `caption_just`, `footnote_just`, `content_just`, `overflow_action` —
  enumerated settings validated by `match.arg()`; they always have a concrete
  default, so an `NA` signals a construction bug and should error rather than
  silently pick a default. (Per the fail-loud principle in the global
  robustness guidance.)
- `gp`, `preview`, `newpage`, `x` — not presence toggles; `NA` is not a
  meaningful "absent" value for them.

**Boundary:** Only a *single* `NA` is absent. A longer vector containing `NA`
among real values (e.g. `c("a", NA, "b")`) is untouched — it collapses with
`"\n"` exactly as before, so genuine multi-line content is never silently
dropped.

**Tests:** `tests/testthat/test-normalize.R` covers `.is_single_na()`,
`normalize_text(NA)`, and `normalize_rule(NA)`; `test-export_tfl_page.R` covers
the end-to-end NA-as-absent behavior for each argument and the mixed-vector
boundary.
