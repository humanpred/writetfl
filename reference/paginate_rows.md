# Split rows into pages, respecting group boundaries

Split rows into pages, respecting group boundaries

## Usage

``` r
paginate_rows(
  data,
  row_heights_in,
  cont_row_h,
  header_row_h,
  content_height_in,
  group_vars,
  row_cont_msg,
  group_rule
)
```

## Arguments

- data:

  Data frame.

- row_heights_in:

  Numeric vector of row heights in inches.

- cont_row_h:

  Height of a continuation-marker row in inches.

- header_row_h:

  Height of the column header row (0 if suppressed).

- content_height_in:

  Available content height per page.

- group_vars:

  Character vector of group column names.

- row_cont_msg:

  Text for continuation-marker rows.

- group_rule:

  Logical — are group rules drawn?

## Value

A list of row-page specs (see internal structure below).
