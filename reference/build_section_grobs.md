# Build all section grobs for a page

Build all section grobs for a page

## Usage

``` r
build_section_grobs(norm_inputs, resolved_gps, caption_just, footnote_just)
```

## Arguments

- norm_inputs:

  Named list of normalize_text() outputs for all 8 elements:
  header_left, header_center, header_right, caption, footnote,
  footer_left, footer_center, footer_right.

- resolved_gps:

  Named list of resolve_gp() outputs for all 8 elements.

- caption_just, footnote_just:

  Justification strings.

## Value

Named list of grobs (NULL where element is absent).
