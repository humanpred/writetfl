# Specify how strings are broken when wrapping table text

A `wrap_breaks` object lists the characters at which
[`.wrap_string()`](https://humanpred.github.io/writetfl/reference/dot-wrap_string.md)
is allowed to insert a line break. Two modes are supported:

## Usage

``` r
wrap_breaks(drop = c(" ", "\t"), keep_before = character(0L))
```

## Arguments

- drop:

  Character vector of single-character break points consumed at the
  break. Defaults to `c(" ", "\t")`.

- keep_before:

  Character vector of single-character break points preserved on the
  left of the break. Defaults to `character(0)`.

## Value

A list of class `"wrap_breaks"` with components `drop` and
`keep_before`.

## Details

- `drop` characters are consumed at the break point. The default (`" "`
  and `"\t"`) means runs of whitespace disappear when a wrap occurs
  there but stay inline otherwise.

- `keep_before` characters stay on the left of the break - the character
  is preserved at the end of the upper line and the *next* character
  starts the new line. Typical use: `"-"` so that a hyphenated term like
  `"placebo-controlled"` can wrap to `"placebo-\ncontrolled"`.

`drop` and `keep_before` must be disjoint single-character vectors.
