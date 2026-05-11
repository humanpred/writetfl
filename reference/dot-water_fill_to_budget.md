# Water-fill widths down to a target budget, given pre-computed minimums

Pure water-from-top: at each iteration find the widest set of
wrap-eligible columns above their floor (`widths_min`) and shrink them
together until they meet the next-widest competitor, hit a floor, or
absorb the remaining excess. Returns the per-column widths summing to
`≤ budget_in + eps` when feasible.

## Usage

``` r
.water_fill_to_budget(widths_in, widths_min, wrap_eligible, budget_in)
```

## Arguments

- widths_in:

  Numeric vector of starting widths in inches.

- widths_min:

  Numeric vector of per-column floors in inches.

- wrap_eligible:

  Logical vector; only `TRUE` columns participate in shrinking.

- budget_in:

  Numeric target sum for `widths_in`.

## Value

Numeric vector of resulting widths.

## Details

Unlike
[`.compute_wrapped_widths()`](https://humanpred.github.io/writetfl/reference/dot-compute_wrapped_widths.md),
this helper does *not* re-measure the per-column floors from cell
content — it trusts the supplied `widths_min` vector. Use this when the
floors are computed once and applied to many sub-problems (per-page
water-fill under the `col_split_strategy = "balanced"` pipeline).

If `sum(widths_min) > budget_in`, the function returns the widths
clamped to the floors (sum may still exceed budget); the caller is
responsible for detecting that case and paginating differently.
