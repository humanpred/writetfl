# Wrap text to fit a target width, preserving paragraph breaks.

Greedy left-to-right packing. Paragraphs (separated by `\n` in `text`)
are wrapped independently and the results re-joined with `\n`. Within a
paragraph the break-character spec controls where breaks may occur; a
single token wider than `available_w_in` is emitted unchanged on its own
line because there is no valid break point inside it.

## Usage

``` r
.wrap_string(text, available_w_in, gp, breaks = wrap_breaks_default())
```

## Arguments

- text:

  Single character string.

- available_w_in:

  Numeric, available width in inches.

- gp:

  A [`gpar()`](https://rdrr.io/r/grid/gpar.html) for measurement font
  context.

- breaks:

  A `wrap_breaks` object; if `NULL`, the package default.

## Value

A single character string, possibly with `\n` inserted at break points.
