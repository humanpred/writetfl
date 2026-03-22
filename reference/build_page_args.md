# Build merged argument list for a single page

Merges page list elements, dots, and page_num with correct precedence:
`x[[i]]` \> dots \> page_num fills footer_right only if absent.

## Usage

``` r
build_page_args(page_list, dots, page_num, i, n)
```

## Arguments

- page_list:

  Named list for this page (from `x[[i]]`).

- dots:

  List of arguments from ... in export_fig_as_pdf.

- page_num:

  Glue template string or NULL.

- i:

  Current page index.

- n:

  Total page count.

## Value

Named list of arguments ready for do.call(export_figpage_to_pdf, .)
