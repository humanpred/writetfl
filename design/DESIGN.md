# Design Rationale — writetfl

This document explains *why* each major design decision was made.
Read alongside `ARCHITECTURE.md` and `DECISIONS.md`.

---

## Why `grid` viewports instead of `ggplot2::theme()` alone?

`ggplot2::theme(plot.margin = ...)` controls whitespace *inside* the ggplot
grob — between the panel and the edge of the ggplot object. It cannot reserve
space at the PDF page level for content that is not part of the plot (running
headers, page numbers, captions that live outside the figure).

`grid` viewports create a coordinate system hierarchy on the page. Pushing an
`outer_vp` inset from the page edges gives a hard outer margin that nothing —
not even the ggplot object — can violate. Within that, a `content_vp` is pushed
whose height is dynamically computed from the measured heights of surrounding
text sections. This gives precise, font-metric-aware layout.

`grid.text()` / `grid.draw()` coordinates are always relative to the currently
active viewport, so annotations placed while `outer_vp` is active are guaranteed
to land in the annotation zone.

---

## Why measure grob height with a fallback?

`grobHeight()` on a multi-line `textGrob` can be unreliable across platforms
and font backends — it sometimes returns only the height of the last line rather
than all lines. The fallback `nlines * stringHeight("M")` is a conservative
estimate using cap-height as a per-line proxy. Taking `max(primary, fallback)`
ensures the content area is never accidentally made too tall by an underestimated
text section.

The measurement must happen while the target viewport is active because font
metrics (`stringHeight`, `stringWidth`) are resolved relative to the current
device resolution and viewport transformation.

---

## Why does `footer_right` beat `page_num`?

`page_num` is a convenience default. The user may wish to override the page
number on specific pages (e.g., a title page with no number, or a page with a
custom scheme). By giving `footer_right` priority, any individual page can
suppress or replace the page number without a special escape mechanism.

---

## Why does `x[[i]]` beat direct arguments?

The intended pattern is that `x` is a list of page specifications (possibly
generated programmatically) and the direct arguments to `export_tfl_page()`
serve as **defaults** applying to all pages unless overridden per-page. This
matches the ggplot2 idiom where layer-level aesthetics override plot-level
defaults. If a page element specifies `caption = "specific caption"`, that
should always win over a default caption passed via `...`.

---

## Why fit rules inside padding rather than adding space?

Adding space for rules would mean that enabling a rule changes the content
height, which is counterintuitive when doing layout-sensitive work like aligning
content across pages. Fitting rules inside the padding gap keeps the content
height invariant to whether rules are shown, as long as padding is large enough
to accommodate the rule visually. Users who want a more prominent rule should
increase `padding`.

---

## Why accept `linesGrob` directly for rules?

This gives power users full control over rule appearance (color, linewidth,
linetype, dash pattern) without adding a combinatorial explosion of
`header_rule_gp`, `header_rule_lty`, etc. arguments. Simple users use `TRUE`;
power users pass a pre-built `linesGrob`.

---

## Why collect all errors before drawing?

Drawing to a PDF device is not transactional — if we draw half a page and then
error, the device is left in an inconsistent state. Collecting all layout errors
during the planning phase and aborting before any drawing ensures each page is
either fully drawn or not touched. The `on.exit(dev.off(), add = TRUE)` in
`export_tfl()` handles device cleanup if an abort occurs mid-loop.

---

## Why `normalize_text()` returns both `$text` and `$nlines`?

The `nlines` count is needed independently of the grob for the fallback height
calculation. Separating concerns (normalization vs. measurement) makes each
function independently testable and avoids having `measure_grob_height()` do
string parsing.

---

## Why `on.exit(dev.off(), add = TRUE)`?

`add = TRUE` preserves any `on.exit` handlers the caller may have registered.
Without it, our `dev.off()` would replace the caller's handler, potentially
causing resource leaks in calling code.

---

## Why return `invisible(normalizePath(file, mustWork = FALSE))`?

- `invisible()` — no console noise in normal use
- `normalizePath(..., mustWork = FALSE)` — resolves relative paths to absolute
  paths even before the file exists (it has not been written when the function
  returns)
- Returning the path enables piping:

```r
export_tfl(plots, "report.pdf") |> browseURL()
```

---

## Why `draw_content()` as a dispatch helper?

Isolating content drawing in a single helper with clear extension points makes
future generalization (additional grob types, `recordedPlot`, `patchwork`) a
matter of adding branches to one function rather than threading conditional
logic through the main layout code. The current implementation handles ggplot
objects and any grid grob.

---

## Why does `export_tfl_page()` accept but not use the `preview` flag?

`export_tfl_page()` calls `grid.newpage()` by default. The `preview` parameter
is accepted for documentary clarity (communicating to callers which mode is
intended) and forward-compatibility. In practice, both normal and preview modes
call `grid.newpage()` — in normal mode the PDF device advances its page, and
in preview mode a new page is drawn on the current device.

The one exception is the `newpage` argument (default `TRUE`). `export_tfl()`
passes `newpage = FALSE` for the **first** page in normal mode so drawing
reuses the blank page the shared metric device (D-48) already opened during
pagination measurement, rather than advancing past it and emitting a spurious
leading blank page. See **D-51** for the full rationale. With `newpage = FALSE`
the function resets the viewport stack with `grid::upViewport(0)` in place of
`grid.newpage()`.

---

## Why does `export_tfl()` preview mode return `invisible(NULL)`?

The original implementation returned `invisible(list_of_grobs)` captured via
`grid::grid.grab()` after each page draw. This caused a **double-render bug**:
the figure appeared once from `export_tfl_page()`'s draw call and again when
the captured grob was processed (by knitr's output hooks or similar). Removing
`grid.grab()` entirely fixes the duplicate. Preview mode is a pure side-effect
operation; callers who need to capture output should use the graphics device
directly.

---

## Why does `tfl_table()` defer all measurement to export time?

Column widths, row heights, and page counts all depend on page dimensions,
margins, and annotation content (which affect the available content area).
None of this is known when `tfl_table()` is called. Deferring to
`tfl_table_to_pagelist()` (called by `export_tfl()`) lets the table use the
exact same content area that the page renderer will produce, ensuring
pagination is consistent with the actual output.

---

## Why a single device per `export_tfl()` call? (D-48)

Font metrics (`stringHeight`, `stringWidth`, `grobHeight`) require an active
graphics device.  Earlier designs opened ~8 small scratch `pdf(...)` devices
across the pagination pipeline; D-48 collapsed them all to **one** device per
`export_tfl()` call:

- **Normal mode (`preview = FALSE`):** the S3 dispatcher calls
  `.open_metric_device()` immediately on entry, which opens
  `grDevices::pdf(file, width = pg_width, height = pg_height)` and
  registers an `on.exit` handler on the dispatcher's frame.  Pagination
  measurements and the per-page draw loop both run on this device.
  `on.exit` ensures the device closes cleanly even if pagination errors
  out (a long-running R session would otherwise leak file handles up to
  the 64-device limit).

- **Preview mode:** the dispatcher opens a transient `pdf(NULL, ...)` for
  pagination, closes it explicitly via `.close_metric_device()` after
  pagination, and lets the per-page draw loop target the user's
  pre-existing device.  This keeps preview-mode pagination decisions
  byte-for-byte identical to normal mode (both run on PDF font metrics
  with matching page dimensions).

All internal measurement helpers — `compute_table_content_area()`,
`.resolve_natural_widths()`, `.run_pagination_iter()`,
`.compute_col_min_widths()`, `.compute_wrapped_widths()`,
`.height_balance_widths()`, `.gt_grob_height()`, `.rtables_lpp_cpp()` —
now **require** an active device with matching page dimensions.  The
contract is enforced by a `dev.cur() == 1L` safety guard inside
`.measure_text_dims_in()`: a regression that calls a helper without a
device fails fast with a clear "requires an active graphics device"
abort, rather than producing silently wrong measurements.

---

## Why thread `text_dim_cache` from pagination to the drawing phase? (D-48)

D-47 introduced a process-wide `(gp_key, string) -> list(w, h)` cache
shared across the natural-width pass, the row-height pass, and the
header-height pass.  D-46 added a per-column `clip_width_caches` shared
across all pages of one `tfl_table`.

D-48 extends both: the pagination cache is **attached to every
`tfl_table_grob` in the pagelist** (via `x$text_dim_cache`).
`drawDetails.tfl_table_grob` extracts it; `.draw_cell_text()` consults it
before falling through to the per-column `width_cache` and finally to
fresh measurement.

The pre-D-48 boundary was justified by "the render device may differ
from pagination's scratch device" — but after D-48 there *is no
difference* in normal mode (pagination and rendering both happen on
`pdf(file)`).  In preview mode the dispatcher attaches an **empty** env
so every lookup misses and the function falls back to per-cell
measurement on the user's render device — preserving today's preview
behaviour exactly.

---

## Why store `cell_heights_in_mat` and `cont_row_h_in` in the gTree?

The `drawDetails` method is called by `grid` at render time, potentially long
after paginate time. Pre-computing cell heights during pagination (when the
metric device is open) and caching them in the grob avoids re-measurement
at draw time and ensures layout consistency: the heights used for pagination
and the heights used for drawing are identical.

The grob caches the *full* per-cell height matrix rather than per-row
scalars because the per-row height for a given page depends on which other
rows are on that page (suppression resets per page; multi-row group spans
absorb deficit jointly).  Each page spec separately carries its committed
`row_heights_in` so drawing reads the exact same heights pagination decided
on, while the matrix supports the fallback path if that cache is missing.

---

## Why a per-cell height matrix instead of per-row scalars?

Issue #29 introduced HTML-`rowspan`-style flow for multi-line group labels.
The label of a group column should be allowed to flow downward through the
suppressed cells beneath it, so a 2-line label spanning two single-line
rows costs 2 lines, not 3.  Implementing that requires answering, for any
(row, column) pair, "what is the natural height of this cell ignoring its
neighbours?" — i.e. a per-cell measurement.  Per-row scalars cannot
represent this without losing the column dimension.

The matrix also lets the per-page row-height resolver recompute heights
when suppression boundaries shift between pages (e.g. when a group is
split across pages and the label re-appears on the second page), without
re-doing the expensive `grobHeight()` measurements.

---

## Why innermost-group first in `.compute_page_row_heights()`?

Outer-group spans are always supersets of (or equal to) inner-group spans
because `.compute_cell_suppression()` resets the inner `last_val` whenever
any outer column changes.  Processing inner spans first means the row
heights already absorb whatever growth the inner labels demanded by the
time outer spans are evaluated; the outer label "borrows" any extra space
the inner pass added.  Reversing the order would compute outer growth
against pre-inner heights and then over-grow when inner labels later need
more space.

The deficit always lands on the *first row* of the span because
`.draw_cell_text()` anchors labels to the top-of-cell (`just = c(.., "top")`).
Growing a later row in the span would not make the top-anchored label any
more visible — extra space would simply appear below the label inside an
already-drawn row.

---

## Why use rotated side labels for `col_cont_msg` instead of `footer_center`?

The original approach injected `col_cont_msg` into `footer_center` of the page
layout. This had two problems:
1. It silently overrode any user-supplied `footer_center` content.
2. It placed a table-internal message in the page frame rather than near the
   table itself.

Rotated side labels (drawn inside the table grob's viewport) are visually
associated with the table, do not interfere with page-level annotation, and are
suppressed automatically when `col_cont_msg = NULL`.

---

## Why are group columns validated to be first in `x`?

The table renderer prepends group-column indices to every column-page group.
If group columns were scattered throughout the column order, they could not be
reliably re-prepended without reordering data columns, which would produce a
table whose display order differs from the source data frame. Requiring group
columns to appear first (matching `dplyr::group_vars()` order) makes the
contract explicit and the rendering predictable.

---

## Why `"lines"` units are valid but `"inches"` is the recommended default for margins?

`"lines"` is resolved relative to the **current font size** at the time the
viewport is pushed. At the root viewport this is the device default, which
varies by platform and device. For outer page margins where absolute precision
is required (e.g., a 0.5-inch margin requirement in a regulatory submission),
`"inches"` or `"mm"` are more predictable. The `padding` argument uses
`"lines"` deliberately, because inter-section spacing that scales with font
size is usually the right behaviour.

---

## Why does `overflow_action` default to `"error"` and not `"warn"`?

Issue #30 calls out that too-wide content should produce a clear signal that
the user can downgrade to a warning *for diagnosis*. The reverse — silent
overflow with an opt-in error — was the prior status quo for several content
shapes (single-column overflow with group columns, raw user grobs wider than
the page, gt/rtables grobs that exceed the content area). Defaulting to
`"error"` reverses that: anything that cannot fit is surfaced immediately,
and the user explicitly opts into `"warn"` to inspect the broken layout.

The error message always includes the literal hint
`Set \`overflow_action = "warn"\` to convert this error to a warning and
still produce output for diagnosis.` so the escape hatch is always one
keystroke away. We resisted introducing a third `"silent"` level: silent
overflow is the bug we're fixing, and an opt-out would re-open it.

---

## Why one `overflow_action` knob across page-level, total, and per-column checks?

Issue #30 frames the problem as a single user-facing concept ("content too
wide"); it would be confusing to expose three separate parameters with
similar but slightly different semantics. The three internal call sites
(`export_tfl_page()` page-level grob check, `compute_col_widths()` total
check, `compute_col_widths()` per-column check) collapse onto one knob via
the small private `.overflow_signal()` helper in `R/layout.R`, which is the
only function that actually knows the difference between `"error"` and
`"warn"`. Each call site composes its own message; the helper handles
dispatch and appends the diagnostic-mode hint.

The same knob now also gates the row-overflow guard added with the wrap
module (issue #28): a single row whose wrapped height exceeds one page is
fundamentally the same family of fault — output the user wrote that
cannot fit the layout they configured. Re-using `overflow_action` keeps
the user model symmetric across width and height.

This also keeps the API surface aligned with `min_content_height` (a single
top-level argument controlling a single layout invariant) rather than with
`overlap_warn_mm` (a tuning knob in `...`). Width overflow is a
correctness-affecting condition, not a tuning detail.

## Why a separate `R/wrap.R` module instead of leaving the algorithm in `R/table_columns.R`?

The wrap algorithm is a self-contained concern with three responsibilities
that are independent of column-width computation: tokenize a string under
a configurable break spec, decide whether a column is wrap-eligible, and
narrow wrap-eligible columns under a fairness rule. Bundling these in a
single file makes the disable case (`wrap_cols = FALSE`) trivial to
reason about — every code path that consults `tbl$wrap_breaks` lives in
one place — and makes the read-and-review unit one file rather than three.

The user explicitly asked for this as a robustness lever: "make it a
separate module that can be easily disabled in case it does something in
a way that the user would not want." Keeping the file boundary clean
makes future replacement (e.g. swapping in a Knuth-style optimal-break
algorithm) a single-file change.

## Why "water-from-top" instead of one-column-at-a-time narrowing?

The prior `.apply_col_wrapping()` shrank the *single* widest
wrap-eligible column by the entire excess every iteration. That converges
but produces an unfair distribution: the widest column repeatedly takes
the whole hit until it bottoms out at `min_col_width`, then the next
widest takes the remainder, and so on. For a table with three columns of
similar widths this leaves one column at minimum and two essentially
unchanged.

Water-from-top instead identifies *all* columns at the current maximum
width and shrinks them together, stopping the step at whichever comes
first: the next-lower competitor (so the active set grows), a column
floor, or the remaining excess. This produces a balanced shrink — the
widest columns end up tied just above the next-widest, and so on,
matching the user's stated preference: "start with the widest column and
consider it first then when it starts getting shrunk too much start
including the narrower columns."

The algorithm is still O(n²) and deterministic, but each iteration makes
strictly more progress in the visible-fairness sense.

## Why a per-column wrap *floor* equal to the longest unbreakable token?

A column cannot be narrower than its widest unbreakable token (after
break characters are applied). Setting only `min_col_width` as the floor
allows the algorithm to shrink the column below the rendered width of
its own content, after which the cell renders with overflow at draw
time. The pagination decisions (row heights, page splits) are then
based on a width that is impossible to honour visually.

Instead, the wrap module computes per wrap-eligible column the rendered
width of the longest unbreakable token across the column's strings (data
+ header) and uses `max(min_col_width, longest_token_width + h_pad)` as
the floor. This keeps the algorithm honest: a width the algorithm
chooses is a width the renderer can actually deliver.

For the user this also means setting a small `min_col_width` is safe —
the wrap module will never shrink a column below what its content
literally requires.

## Why is text-wrap the default but page-column-split is independent?

The two concepts answer different user questions:

- **Text-wrap (`wrap_cols`):** "Can this column be narrower so the
  table fits one page width?"
- **Page-column-split (`allow_col_split`):** "If the table cannot fit on
  one page width, can I spread its columns across multiple pages?"

Text-wrap is reversible at the data level (the cell content survives;
only the line breaks change). Page-column-split is a layout decision
that fragments the visual unit. Defaulting text-wrap on but leaving
page-split's existing default (`TRUE`) preserves the prior auto-split
behaviour while removing the single biggest cause of unintended overflow
— a wrappable string column wider than the page.

The two also compose naturally: text-wrap runs first, narrowing what it
can; if the result still does not fit and `allow_col_split = TRUE`, the
splitter spreads the (narrower) columns across pages.

The user observed casually that the names of the two concepts could be
read as the same thing. The vignette and the roxygen for both arguments
now spell out the distinction explicitly so the names cannot be
misread.
