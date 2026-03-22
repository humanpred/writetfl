# Check for horizontal overlap between left/center/right elements

Checks for overlap within a single row (header or footer). Errors are
collected and returned; near-miss warnings are issued immediately via
rlang::warn().

## Usage

``` r
check_overlap(widths, vp_width_in, overlap_warn_mm = 2, row_name = "header")
```

## Arguments

- widths:

  Named list with elements `left`, `center`, `right` (numeric inches, or
  NULL when element is absent).

- vp_width_in:

  Viewport width in inches.

- overlap_warn_mm:

  Near-miss threshold in mm. NULL skips all detection.

- row_name:

  Prefix used in error/warning messages ("header" or "footer").

## Value

Character vector of error messages (length 0 if no errors).
