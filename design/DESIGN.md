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

`export_tfl_page()` always calls `grid.newpage()`. The `preview` parameter is
accepted for documentary clarity (communicating to callers which mode is
intended) and forward-compatibility. In practice, both normal and preview modes
call `grid.newpage()` — in normal mode the PDF device advances its page, and
in preview mode a new page is drawn on the current device.

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

## Why does `tfl_table_to_pagelist()` open a scratch PDF device?

Font metrics (`stringHeight`, `stringWidth`, `grobHeight`) require an active
graphics device. A scratch `pdf(NULL, ...)` device is opened at measurement
time to provide a consistent rendering context (same page dimensions as the
final output) without writing to disk.

---

## Why store `row_heights_in` and `cont_row_h_in` in the gTree?

The `drawDetails` method is called by `grid` at render time, potentially long
after paginate time. Pre-computing row heights during pagination (when a
scratch device is already open) and caching them in the grob avoids opening
another device at draw time and ensures layout consistency: the heights used
for pagination and the heights used for drawing are identical.

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
