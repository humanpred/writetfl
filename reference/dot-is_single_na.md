# Test whether `x` is a single `NA` to be treated as absent (like `NULL`)

A length-1 atomic vector holding `NA` (of any type: logical `NA`,
`NA_character_`, `NA_integer_`, ...). Used so that data-driven page
construction can pass `NA` for an unsupplied annotation or toggle and
have it treated the same as `NULL`. A longer vector containing `NA`
among real values is *not* a single `NA` and is left untouched.

## Usage

``` r
.is_single_na(x)
```

## Arguments

- x:

  Any object.

## Value

`TRUE` only when `x` is a length-1 atomic `NA`.
