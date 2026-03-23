# Convert content dimensions to lines-per-page and chars-per-page

Convert content dimensions to lines-per-page and chars-per-page

## Usage

``` r
.rtables_lpp_cpp(
  content_h,
  content_w,
  font_family = "Courier",
  font_size = 8,
  lineheight = 1
)
```

## Arguments

- content_h:

  Available content height in inches.

- content_w:

  Available content width in inches.

- font_family:

  Font family name.

- font_size:

  Font size in points.

- lineheight:

  Line height multiplier.

## Value

A list with `$lpp` and `$cpp` (positive integers).
