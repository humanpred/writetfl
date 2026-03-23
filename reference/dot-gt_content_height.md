# Compute available content height for gt table pagination

Reuses
[`compute_table_content_area()`](https://humanpred.github.io/writetfl/reference/compute_table_content_area.md)
to measure how much vertical space the content gets after header,
caption, footnote, and footer sections are accounted for.

## Usage

``` r
.gt_content_height(pg_width, pg_height, dots, page_num, annot)
```

## Arguments

- pg_width, pg_height:

  Page dimensions in inches.

- dots:

  Named list of additional page-layout arguments.

- page_num:

  Glue template for page numbering.

- annot:

  Annotation list from
  [`.extract_gt_annotations()`](https://humanpred.github.io/writetfl/reference/dot-extract_gt_annotations.md).

## Value

Numeric scalar: available content height in inches.
