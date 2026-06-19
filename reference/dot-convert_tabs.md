# Expand tab characters in one line of text to spaces

The PDF graphics device cannot measure or render the tab glyph (0x09):
it warns "font width unknown" and treats the tab as zero width, so a tab
in cell or page text would silently collapse. Tabs are therefore
expanded to spaces before any measuring or drawing.

## Usage

``` r
.convert_tabs(s, ..., tab_indent_spaces = 2L, tab_infix_spaces = 1L)
```

## Arguments

- s:

  A single character string with no embedded newline.

- ...:

  Ignored.

- tab_indent_spaces:

  Number of spaces a *leading* (indentation) tab — one preceded only by
  whitespace — is expanded to. Default `2`, matching the common "a tab
  indents by two spaces" convention.

- tab_infix_spaces:

  Number of spaces an *in-line* tab — one with non-whitespace to its
  left — is expanded to. Default `1`; the resulting space then behaves
  as an ordinary breakable space.

## Value

`s` with tab characters replaced by spaces. Strings containing no tab
are returned untouched (fast path).
