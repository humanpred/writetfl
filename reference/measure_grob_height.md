# Measure grob height conservatively (primary + nlines fallback)

Measure grob height conservatively (primary + nlines fallback)

## Usage

``` r
measure_grob_height(grob, nlines)
```

## Arguments

- grob:

  A grob object, or NULL.

- nlines:

  Integer line count from normalize_text().

## Value

Numeric height in inches. Returns 0 if grob is NULL.
