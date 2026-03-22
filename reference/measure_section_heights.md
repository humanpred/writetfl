# Measure heights of all five sections

Header and footer heights are the MAX of their left/center/right grobs,
since all three occupy the same row. Called while outer_vp is active.

## Usage

``` r
measure_section_heights(
  header_grobs,
  caption_grob,
  footnote_grob,
  footer_grobs,
  norm_texts
)
```

## Arguments

- header_grobs:

  Named list: left, center, right grobs (or NULL).

- caption_grob:

  A grob or NULL.

- footnote_grob:

  A grob or NULL.

- footer_grobs:

  Named list: left, center, right grobs (or NULL).

- norm_texts:

  Named list of normalize_text() outputs for all 8 elements.

## Value

Named list: header, caption, footnote, footer (numeric inches).
