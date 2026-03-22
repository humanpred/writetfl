# Compute available content area for a tfl_table page

Opens a scratch PDF device, measures annotation section heights using
the same infrastructure as export_tfl_page(), and returns available
width and height in inches.

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
  fn_just
)
```
