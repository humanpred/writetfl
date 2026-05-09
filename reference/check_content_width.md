# Check content width against an upper bound and signal if too wide

Mirrors
[`check_content_height()`](https://humanpred.github.io/writetfl/reference/check_content_height.md)
but is a maximum-ceiling check rather than a minimum-floor check, and
accepts an `overflow_action` knob that downgrades the error to a warning
so output can still be produced for diagnosis (see issue \#30).

## Usage

``` r
check_content_width(
  content_w_in,
  vp_width_in,
  overflow_action,
  errors,
  what = "Content"
)
```

## Arguments

- content_w_in:

  Natural width of the content in inches.

- vp_width_in:

  Available content viewport width in inches.

- overflow_action:

  One of `"error"` (default) or `"warn"`.

- errors:

  Character vector to append to (when action is `"error"`).

- what:

  Label for the source of the width (e.g. `"Content"`, `"Column 'x'"`,
  `"Total column width"`).

## Value

Updated `errors` character vector.
