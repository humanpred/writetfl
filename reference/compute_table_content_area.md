# Compute available content area for a tfl_table page

Opens a scratch device, measures annotation section heights using the
same infrastructure as export_tfl_page(), and returns available width
and height in inches. When `for_preview = TRUE`, the scratch device
matches the current raster device's font metrics.

## Usage

``` r
compute_table_content_area(
  pg_width,
  pg_height,
  margins,
  padding,
  header_rule,
  footer_rule,
  annot,
  gp_page,
  cap_just,
  fn_just,
  for_preview = FALSE,
  scratch_dpi = NULL
)
```
