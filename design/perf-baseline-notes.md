# Performance baseline notes — single-device + cache-through-drawing refactor

Working notes captured during Phase 0 of the refactor that extends
PR #39 with three layered changes:

1. Single device per `export_tfl()` call (eliminate scratch
   `pdf()` opens in `R/`).
2. Cache the pagination-phase text-dim measurements through to
   `.draw_cell_text()` (D-47's cache currently stops at the render-
   device boundary).
3. Unify the four small per-purpose caches around the shared
   `.measure_text_dims_in()` helper.

Baseline HEAD: `b196ca3` ("Consolidate width+height measurement into one
cache during pagination"; D-47 in `design/DECISIONS.md`).

The user explicitly rejected premature optimization
(`memory/project_perf_profiling.md`). Profile-first, then commit only
the changes the data plus the maintainability argument justifies.

## Wall-clock baseline (bench_focused.R, n = 30)

| Scenario       | min       | median    | iqr      |
|----------------|-----------|-----------|----------|
| `iris5p`       | 209 ms    | 231 ms    | 21.9 ms  |
| `big_df`       | 1.06 s    | 1.16 s    | 100 ms   |
| `wrap_heavy`   | 1.79 s    | 1.94 s    | 152 ms   |
| `preview_iris` | 143 ms    | 155 ms    | 11.4 ms  |
| `figure_multi` | 528 ms    | 601 ms    | 73.1 ms  |

These will be the comparison baselines for every later commit.

## Profile snapshots (profile_writetfl.R --quick, Rprof @ 0.01s)

Top writetfl source lines by self-time, summarised across the four
core scenarios. **The percentages are self/total of *Rprof samples*
during a 20-rep loop**, so they capture relative cost, not absolute
time.

### `core_paginate` (iris -> ~5 pages)

| Line                       | self.pct | total.pct | What it is                              |
|----------------------------|----------|-----------|-----------------------------------------|
| `table_draw.R#412`         | 1.4 %    | **55.7 %**| `.draw_cell_text(display_str, cs$align, ...)` call site |
| `table_draw.R#625`         | 0.4 %    | **47.9 %**| inside `.draw_cell_text` (cap clip + grid.text) |
| `table_utils.R#339`        | 1.1 %    | 2.5 %     | `.fmt_cell_vec()` body                  |
| `resolve_gp.R#15`          | 1.1 %    | 1.1 %     | `merge_gpar()` field loop               |
| `table_draw.R#606`         | 0.7 %    | **8.9 %** | `text_w <- .measure_text_width_in(...)` — D-47 boundary line, Phase 3 target |
| `wrap.R#168`               | 0.7 %    | 0.7 %     | `.measure_text_width_in()` body         |
| `table_utils.R#250`        | 0.35 %   | 11.7 %    | `.measure_max_string_width()` body      |
| `table_rows.R#71/81/83`    | 0.35 %   | 1–3 %     | row-height measurement loop             |

### `core_wrap` (clinical_df with wrap_balance = "height")

| Line                       | self.pct | total.pct | What it is                              |
|----------------------------|----------|-----------|-----------------------------------------|
| `wrap.R#139`               | 2.5 %    | 3.3 %     | inside `.wrap_paragraph` token loop     |
| `table_utils.R#250`        | 0.8 %    | **33.1 %**| `.measure_max_string_width()` — natural-width pass |
| `wrap.R#168`               | 0.8 %    | 1.2 %     | `.measure_text_width_in()` body         |
| `wrap.R#108/138/128`       | 0.4–0.8 %| 0.8–1.2 % | wrap break + token width                |
| `resolve_gp.R#14/15/32`    | 0.4–1.2 %| 0.8–2.1 % | gpar resolution                         |
| `table_utils.R#99`         | 0.4 %    | 7.4 %     | `.measure_header_row_height()`          |
| `table_utils.R#301`        | 0.4 %    | 2.5 %     | (cache lookup helper)                   |

### `core_small` (mtcars 20 rows, 1 page)

No single writetfl source line above 1.6 %. Top R functions are
generic grid plumbing (`$`, `valid.charjust`, `grid.Call`, `<GC>`,
`numnotnull`). For a small one-page table the per-grid-call overhead
dominates and there's little to optimise at the writetfl level.

### `figure_multi` (10 ggplot pages)

writetfl source lines all under 0.3 %. ggplot's `FUN`, `vapply`,
`enexpr`, `fetch_ggproto`, and grid's `grid.Call.graphics` dominate.
**Phase 1/2 device-lifecycle changes should not affect this scenario.**
We will keep watching it to confirm no regression.

## Where is `pdf()` / `dev.off()` in the profile?

Neither shows in the top-20 self-time list for any scenario. Estimated
combined `(pdf + dev.off)` cost: **well below 3 %** of total in every
scenario.

This is the Phase-0 go/no-go signal for Phase 1/2. Strict perf-only
gate says **skip** — but the user explicitly said maintainability
counts (one cache contract, one device-lifecycle helper, no scratch
`pdf()` opens scattered across seven files). Phase 1/2 proceeds on
maintainability grounds.

## Where is `.measure_text_width_in` in the profile?

`table_draw.R#606` (the re-measure inside `.draw_cell_text`) lands at
**8.9 %** of total time in `core_paginate`. The enclosing
`.draw_cell_text` body at `table_draw.R#625` reaches **47.9 %** of
total (it dominates the per-page draw loop). Removing the re-measure
when the pagination cache already covers the cell is a real perf win.

Phase 3 proceeds on perf grounds.

## Where is the wrap measurement loop?

`wrap.R#139` and surrounding lines accumulate ~2–4 % self-time in
`core_wrap` but no single line is dominant. The natural-width pass at
`table_utils.R#250` shows 33.1 % *total* in `core_wrap` —
this is the path D-47 already speeds up. Unifying the cache
(Phase 3.5) should not change this number much; it just removes the
need for each cache consumer to invent its own env shape.

Phase 3.5 proceeds on maintainability grounds.

## Decision matrix

| Phase                         | Perf signal?      | Maintainability? | Proceed?  |
|-------------------------------|-------------------|------------------|-----------|
| 1. Single device              | < 3 % (marginal)  | Yes (strong)     | Yes (maint) |
| 2. Scratch-pdf elimination    | < 3 % (marginal)  | Yes (strong)     | Yes (maint) |
| 3. Cache through drawing      | 8.9 % (strong)    | Yes              | **Yes (perf)** |
| 3.5. Cache unification        | n/a               | Yes (strong)     | Yes (maint) |
| 4. Tests                      | n/a               | Required         | Yes        |
| 5. Profile post-refactor      | n/a               | Required         | Yes        |
| 6. Documentation              | n/a               | Required         | Yes        |

Order of execution (see plan): 3.5 → 3 → 1 → 2 → 4 → 5 → 6. Refactor
the cache shape first (no behavior change), then add the drawing-phase
consumer, then collapse device lifecycle, then enforce the contract.

## Per-scenario expected outcomes

- `iris5p`, `core_paginate`: should improve materially after Phase 3
  (re-measure removed in normal mode). Target: ≥5 % drop on
  `core_paginate` median.
- `big_df`: harder — most of its time is in `grid.Call.graphics`
  (the actual PDF stream emission), not measurement. Small
  improvement expected (~2–5 %) from Phase 3 + smaller from Phase 1/2.
- `wrap_heavy`: Phase 3 helps any wrap cell whose first-line text was
  measured during pagination. The wrap pipeline also measures
  per-token, which Phase 3.5 unification keeps cacheable
  cross-scenario.
- `preview_iris`: expected **no change** — preview mode keeps fresh
  empty cache attached to grobs by design (D-47 boundary preserved).
- `figure_multi`: expected **no change** — non-tfl_table path.

## Snapshot files

Raw Rprof output saved under `examples/profile_output/`:

- `profile_core_small_20260513_083031.Rprof`
- `profile_core_wrap_20260513_083035.Rprof`
- `profile_core_paginate_20260513_083041.Rprof`
- `profile_figure_multi_20260513_083047.Rprof`

These will be regenerated and overwritten by subsequent profile runs.

## What to re-check after each commit

- `Rscript examples/bench_focused.R` — no regression > 2 % on any
  scenario.
- `devtools::test()` — green.

If a commit breaks either, roll back before the next commit.
