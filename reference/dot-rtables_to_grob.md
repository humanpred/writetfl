# Convert a single rtables page to a textGrob

Convert a single rtables page to a textGrob

## Usage

``` r
.rtables_to_grob(
  rt_page,
  font_family = "Courier",
  font_size = 8,
  lineheight = 1
)
```

## Arguments

- rt_page:

  A `VTableTree` object (one paginated page).

- font_family:

  Font family name.

- font_size:

  Font size in points.

- lineheight:

  Line height multiplier.

## Value

A grid `textGrob`.
