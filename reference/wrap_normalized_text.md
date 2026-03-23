# Word-wrap a normalized text to fit within a given width

Takes a normalized text list (from
[`normalize_text()`](https://humanpred.github.io/writetfl/reference/normalize_text.md))
and wraps it to fit within `width_in` inches using greedy line-breaking.
Returns a new normalized text list with updated `text` and `nlines`.

## Usage

``` r
wrap_normalized_text(norm, gp, width_in)
```

## Arguments

- norm:

  Output of
  [`normalize_text()`](https://humanpred.github.io/writetfl/reference/normalize_text.md).

- gp:

  Resolved [`gpar()`](https://rdrr.io/r/grid/gpar.html) for this text
  element.

- width_in:

  Available width in inches.

## Value

A list with `$text` (wrapped string) and `$nlines` (updated count).

## Details

Must be called while a viewport with the target font metrics is active.
