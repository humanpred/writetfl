# Width (inches) of the widest unbreakable token across a column's strings.

This is the wrapping floor: a column cannot be narrowed below the width
needed to render its longest single token. Tabs are expanded to spaces
first (matching the table draw path) so the floor agrees with the
rendered text.

## Usage

``` r
.column_min_token_width_in(strings, gp, breaks, ...)
```

## Arguments

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
