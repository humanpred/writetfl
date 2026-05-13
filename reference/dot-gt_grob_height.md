# Measure a gt grob's height

D-48: requires an active graphics device with matching page dimensions;
`export_tfl.gt_tbl()` opens the metric device via
`.open_metric_device()` before invoking the pagelist conversion
pipeline, so
[`convertHeight()`](https://rdrr.io/r/grid/grid.convert.html) here
resolves against that device's font metrics.

## Usage

``` r
.gt_grob_height(grob, pg_width, pg_height)
```

## Arguments

- grob:

  A gtable grob from
  [`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html).

- pg_width, pg_height:

  Page dimensions (advisory; the active metric device's dimensions are
  what `convertHeight` uses).

## Value

Numeric scalar: grob height in inches.
