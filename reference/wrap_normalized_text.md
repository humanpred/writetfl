# Word-wrap a normalized text to fit within a given width

Takes a normalized text list (from
[`normalize_text()`](https://humanpred.github.io/writetfl/reference/normalize_text.md))
and wraps it to fit within `width_in` inches using greedy line-breaking.
Returns a new normalized text list with updated `text` and `nlines`.

## Usage

``` r
wrap_normalized_text(norm, gp, width_in, ...)
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

- ...:

  Arguments passed on to
  [`.convert_tabs`](https://humanpred.github.io/writetfl/reference/dot-convert_tabs.md)

  `tab_indent_spaces`

  :   Number of spaces a *leading* (indentation) tab — one preceded only
      by whitespace — is expanded to. Default `2`, matching the common
      "a tab indents by two spaces" convention.

  `tab_infix_spaces`

  :   Number of spaces an *in-line* tab — one with non-whitespace to its
      left — is expanded to. Default `1`; the resulting space then
      behaves as an ordinary breakable space.

## Value

A list with `$text` (wrapped string) and `$nlines` (updated count).

## Details

Must be called while a viewport with the target font metrics is active.
