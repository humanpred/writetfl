# Exporting table1 Tables

``` r
library(writetfl)
library(table1)
#> 
#> Attaching package: 'table1'
#> The following objects are masked from 'package:base':
#> 
#>     units, units<-
```

The [table1](https://cran.r-project.org/package=table1) package creates
publication-ready “Table 1” summary tables commonly used in clinical and
epidemiological reporting. `writetfl` accepts `table1` objects directly
in
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md),
preserving column labels, bold variable names, indented summary
statistics, and stratification headers.

------------------------------------------------------------------------

## Basic usage

Pass a `table1` object directly to
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md):

``` r
dat <- data.frame(
  age = c(45, 52, 61, 38, 55, 47, 63, 41, 58, 50),
  sex = c("Male", "Female", "Male", "Female", "Male",
          "Female", "Male", "Female", "Male", "Female")
)

tbl <- table1(~ age + sex, data = dat)

export_tfl(tbl, preview = TRUE,
  header_left = "Study Report",
  header_rule = TRUE,
  footer_rule = TRUE
)
```

![](v08-table1_files/figure-html/basic-1.png)

------------------------------------------------------------------------

## Column labels

Use [`table1::label()`](https://rdrr.io/pkg/table1/man/label.html) to
set variable labels. These are used as the bold row headers in the
output:

``` r
label(dat$age) <- "Age (years)"
label(dat$sex) <- "Sex"

tbl <- table1(~ age + sex, data = dat)

export_tfl(tbl, preview = TRUE,
  header_left = "Labeled Variables"
)
```

![](v08-table1_files/figure-html/labels-1.png)

Variable labels appear as bold row headings with the summary statistics
indented beneath them.

------------------------------------------------------------------------

## Caption and footnote

The `caption` and `footnote` arguments to
[`table1()`](https://rdrr.io/pkg/table1/man/table1.html) are
automatically extracted into writetfl’s caption and footnote zones:

``` r
tbl <- table1(~ age + sex, data = dat,
              caption = "Table 1. Baseline Demographics",
              footnote = "ITT Population (N = 10)")

export_tfl(tbl, preview = TRUE,
  header_left  = "Protocol XY-001",
  header_right = "2025-01-15",
  header_rule  = TRUE,
  footer_rule  = TRUE
)
```

![](v08-table1_files/figure-html/caption-footnote-1.png)

------------------------------------------------------------------------

## Stratification

Use the formula interface with `|` to stratify by a grouping variable.
Column headers show the stratum labels and sample sizes:

``` r
dat$trt <- c(rep("Treatment", 5), rep("Placebo", 5))

label(dat$age) <- "Age (years)"
label(dat$sex) <- "Sex"

tbl <- table1(~ age + sex | trt, data = dat,
              caption = "Table 1. Demographics by Treatment Group")

export_tfl(tbl, preview = TRUE,
  header_left = "Study Report",
  header_rule = TRUE,
  footer_rule = TRUE
)
```

![](v08-table1_files/figure-html/stratified-1.png)

The `overall` argument adds a combined column:

``` r
tbl <- table1(~ age + sex | trt, data = dat, overall = "Total",
              caption = "Table 1. Demographics with Overall")

export_tfl(tbl, preview = TRUE,
  header_left = "Study Report",
  header_rule = TRUE
)
```

![](v08-table1_files/figure-html/overall-1.png)

------------------------------------------------------------------------

## Page layout

All
[`export_tfl_page()`](https://humanpred.github.io/writetfl/reference/export_tfl_page.md)
layout arguments work with table1 tables:

``` r
tbl <- table1(~ age + sex | trt, data = dat,
              caption = "Table 1. Demographics")

export_tfl(tbl, preview = TRUE,
  header_left   = "Protocol XY-001",
  header_center = "CONFIDENTIAL",
  header_right  = "2025-01-15",
  footnote      = "Percentages based on non-missing values.",
  footer_left   = "Sponsor: Acme Corp",
  header_rule   = TRUE,
  footer_rule   = TRUE,
  gp = list(
    header  = grid::gpar(fontsize = 11, fontface = "bold"),
    caption = grid::gpar(fontsize = 9, fontface = "italic"),
    footer  = grid::gpar(fontsize = 8)
  )
)
```

![](v08-table1_files/figure-html/layout-1.png)

------------------------------------------------------------------------

## Multiple tables

Pass a list of `table1` objects to create a multi-page PDF:

``` r
tbl_age <- table1(~ age | trt, data = dat,
                  caption = "Table 1a. Age by Treatment")
tbl_sex <- table1(~ sex | trt, data = dat,
                  caption = "Table 1b. Sex by Treatment")

export_tfl(
  list(tbl_age, tbl_sex),
  preview     = TRUE,
  header_left = "Study Report",
  header_rule = TRUE,
  footer_rule = TRUE
)
```

![](v08-table1_files/figure-html/multi-1.png)![](v08-table1_files/figure-html/multi-2.png)

------------------------------------------------------------------------

## Automatic pagination

When a table has too many variables to fit on a single page,
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
paginates automatically. Page breaks fall between variable groups (a
variable label and its summary rows are kept together).

``` r
set.seed(42)
big_dat <- data.frame(
  v01 = rnorm(50), v02 = rnorm(50), v03 = rnorm(50),
  v04 = rnorm(50), v05 = rnorm(50), v06 = rnorm(50),
  v07 = rnorm(50), v08 = rnorm(50), v09 = rnorm(50),
  v10 = rnorm(50), v11 = rnorm(50), v12 = rnorm(50)
)
for (v in names(big_dat)) label(big_dat[[v]]) <- paste("Variable", v)

big_tbl <- table1(
  ~ v01 + v02 + v03 + v04 + v05 + v06 + v07 + v08 + v09 + v10 + v11 + v12,
  data = big_dat,
  caption = "Table 2. Many Variables"
)

export_tfl(big_tbl,
  preview      = 1:2,
  pg_height    = 5,
  header_left  = "Study Report",
  header_rule  = TRUE,
  footer_rule  = TRUE
)
```

![](v08-table1_files/figure-html/pagination-1.png)![](v08-table1_files/figure-html/pagination-2.png)

------------------------------------------------------------------------

## Preserved features

| Feature                                                                 | How it’s handled                                                                                |
|-------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------|
| Column labels ([`label()`](https://rdrr.io/pkg/table1/man/label.html))  | Bold variable-name rows in the table body                                                       |
| Indented summary statistics                                             | Spaces preserved from [`t1flex()`](https://rdrr.io/pkg/table1/man/t1flex.html) conversion       |
| Stratification (`\| group`)                                             | Column headers with stratum labels and N counts                                                 |
| Overall column                                                          | Included when `overall` is set                                                                  |
| Caption                                                                 | Extracted to writetfl caption zone                                                              |
| Footnote                                                                | Extracted to writetfl footnote zone                                                             |
| Custom render functions                                                 | Applied before conversion; output preserved                                                     |
| Variable units ([`units()`](https://rdrr.io/pkg/table1/man/units.html)) | Displayed in variable labels                                                                    |
| Row label heading                                                       | Header for the first column                                                                     |
| CSS styles                                                              | Translated to flextable formatting via [`t1flex()`](https://rdrr.io/pkg/table1/man/t1flex.html) |
| Group-aware pagination                                                  | Variable groups kept together across page breaks                                                |

------------------------------------------------------------------------

## How it works

Under the hood,
[`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
uses [`table1::t1flex()`](https://rdrr.io/pkg/table1/man/t1flex.html) to
convert the table1 object to a
[flextable](https://davidgohel.github.io/flextable/), then renders the
flextable to a grid grob via
[`flextable::gen_grob()`](https://davidgohel.github.io/flextable/reference/gen_grob.html).
This preserves all visual formatting including bold labels, indented
statistics, borders, and spanning headers.

Caption and footnote are extracted from the table1 object’s internal
structure (not the flextable) to ensure they appear in writetfl’s
annotation zones rather than being duplicated inside the table.
