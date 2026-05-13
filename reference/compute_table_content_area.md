# Compute available content area for a tfl_table page

Measures annotation section heights using the same infrastructure as
export_tfl_page() and returns available width and height in inches.

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

## Details

D-48: requires an active graphics device with matching page dimensions;
the caller (`.tfl_table_to_pagelist_default()`) runs inside the metric
device opened by `.open_metric_device()` in the S3 dispatcher, so font
metrics here equal those used at draw time (normal mode) or those of the
same pdf(NULL) used for the rest of pagination (preview mode).
