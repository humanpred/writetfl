# writetfl 0.0.0.9000

* `export_tfl_page()` now treats a single `NA` the same as `NULL` (absent) for
  its annotation and presence-toggle arguments: `caption`, `footnote`,
  `header_left`/`header_center`/`header_right`,
  `footer_left`/`footer_center`/`footer_right` (section element omitted),
  `page_i` (no `"Page <i>: "` error prefix), and `header_rule`/`footer_rule`
  (no rule). This lets data-driven page construction pass `NA` for an
  unsupplied value instead of rendering the literal text `"NA"` or erroring. A
  longer vector containing `NA` among real values is unaffected (D-52).
