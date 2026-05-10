# Troubleshooting writetfl

This guide covers common errors and warnings you may encounter when
using `writetfl`, along with their causes and solutions.

## Content height errors

**Error:** `Content height (X in) is below the minimum (Y in).`

This error means that after reserving space for headers, footers,
captions, and footnotes, there isn’t enough room left for the main
content area.

**Common causes:**

- Very short page height (`pg_height`)
- Large margins
- Lengthy captions or footnotes that consume vertical space
- Multiple annotation sections combined

**Solutions:**

- Increase `pg_height` or decrease `margins`
- Shorten caption/footnote text
- Reduce annotation font sizes via the `gp` argument
- Lower `min_content_height` (default is 3 inches) if your content
  genuinely needs less space:

``` r

export_tfl(x, file = "out.pdf",
           min_content_height = grid::unit(2, "inches"))
```

## Content too wide for the page

**Error message ends with:** `Set \`overflow_action = “warn”\` to
convert this error to a warning and still produce output for
diagnosis.\`

`writetfl` checks three width-overflow conditions and reports the first
one that fires:

1.  **Page-level content grob too wide.** Any non-`ggplot`,
    non-character content
    (e.g. [`gt::as_gtable()`](https://gt.rstudio.com/reference/as_gtable.html),
    an `rtables` text grob, `gridExtra::tableGrob()`, a raw user grob)
    whose natural width exceeds the content viewport.
2.  **`tfl_table` total column width** (only when
    `allow_col_split = FALSE`). The sum of column widths after wrapping
    still exceeds the content area.
3.  **`tfl_table` per-column overflow.** Any single column wider than
    the content area, or any data column whose width *plus* the
    row-header group columns exceeds the page (group columns repeat on
    every column-paginated page, so this case is unrenderable).

The error message identifies which condition fired and includes a
per-column width breakdown for cases (2) and (3).

**Solutions:**

- Word wrapping is on by default (`wrap_cols = "auto"`), but a column
  with a single long unbreakable token (e.g. a 40-character drug code)
  can’t shrink below that token’s rendered width. Either:
  - Pass a
    [`wrap_breaks()`](https://humanpred.github.io/writetfl/reference/wrap_breaks.md)
    spec that lets the algorithm break inside the token:
    e.g. `wrap_breaks(drop = " ", keep_before = c("-", "_"))` for a
    hyphen- or underscore-separated identifier.
  - Or split the column into more shorter columns.
- Enable column splitting: `tfl_table(..., allow_col_split = TRUE)`.
- Force wrap on a column the auto-detect skipped:
  `tfl_table(..., wrap_cols = c("wide_col1", "wide_col2"))`.
- Set narrower fixed widths on specific columns via
  [`tfl_colspec()`](https://humanpred.github.io/writetfl/reference/tfl_colspec.md).
- Increase page width or decrease margins.
- Reduce the number of group columns (group columns repeat on every
  column-paginated page and reserve space for themselves on every page).
- For uneven content density across wrap-eligible columns, opt in to
  `wrap_balance = "height"` — it redistributes width between columns to
  reduce total table height (often fewer pages overall). Falls back
  silently to the default if no improvement is found.

### Diagnosing by inspecting the broken layout

When you can’t immediately tell *why* the layout overflows, pass
`overflow_action = "warn"` to convert the error to a warning and still
produce a PDF. The PDF visibly shows the overflow (clipped by `grid` at
the page edge), which is often the fastest way to identify the offending
column or grob:

``` r

# Default: hard error, no PDF written
export_tfl(tbl, file = "out.pdf")
#> Error: Column 'description' width (12 in) exceeds available content width (7.5 in)
#>   Set `overflow_action = "warn"` to convert this error to a warning ...

# Warn-mode: PDF is written, warning printed for diagnosis
export_tfl(tbl, file = "out.pdf", overflow_action = "warn")
#> Warning: Column 'description' width (12 in) exceeds available content width (7.5 in) ...
```

Use `"warn"` for diagnosis only — it does not fix the layout; it just
lets you see what the renderer was forced to clip.

## Row wrapped to taller than one page

**Error:**
`Row N of the table wraps to a height (X.XX in) that exceeds the available page content height (Y.YY in)…`

A row’s content wrapped to more vertical space than fits on a single
page. Almost always caused by an outsize cell (long narrative pasted
into a column whose width is set very narrow, an unbroken token forced
to wrap to many lines, etc.). No amount of pagination can rescue this
case — text-wrap can’t make the row shorter than its content allows, and
splitting it across pages would leave words mid-sentence at the page
break.

**Solutions (in order of preference):**

- Reduce the offending cell’s content (the input data is almost always
  the right thing to fix here).
- Widen the column so the cell wraps to fewer lines.
- Increase `pg_height` so a multi-line row fits.
- For diagnosis only, pass `overflow_action = "warn"` to
  [`export_tfl()`](https://humanpred.github.io/writetfl/reference/export_tfl.md)
  to see what the renderer would produce. The output PDF will be visibly
  broken (text clipped at the page edge), but it tells you exactly which
  row was responsible.

``` r

export_tfl(tbl, file = "out.pdf", overflow_action = "warn")
#> Warning: Row 3 of the table wraps to a height (12.4 in) that exceeds
#>   the available page content height (7.3 in). Reduce the cell content,
#>   increase the page height, widen the column, or set the column to
#>   wrap less aggressively.
```

## Overlap warnings

**Warning:** `Header/footer elements may overlap`

This warning fires when the combined width of left, center, and right
elements in the header or footer row is close to or exceeds the
available width.

**Solutions:**

- Shorten header/footer text
- Use smaller font sizes for those sections via `gp`
- Remove the center element if left + right are sufficient
- Suppress the warning with `overlap_warn_mm = NULL` if you’ve verified
  the layout is acceptable

## Debugging workflow

### Preview a single page

Use `preview = TRUE` to render directly to the current graphics device
without writing a PDF file. This is useful in RStudio or knitr:

``` r

export_tfl(my_table, preview = TRUE)
```

To preview only specific pages (e.g., pages 1 and 3):

``` r

export_tfl(my_table, preview = c(1, 3))
```

### Inspect a tfl_table before export

Print the `tfl_table` object to see column specs, wrap settings, group
columns, and an approximate page count:

``` r

tbl <- tfl_table(my_data, wrap_cols = c("description"))
print(tbl)
```

### Common pitfalls

- **Group columns must be a prefix of the data frame columns.** If your
  grouped data frame has group columns that aren’t the leftmost columns,
  reorder them before calling
  [`tfl_table()`](https://humanpred.github.io/writetfl/reference/tfl_table.md).

- **[`gpar()`](https://rdrr.io/r/grid/gpar.html) does not preserve names
  on numeric vectors.** When specifying `cell_padding`, use positional
  elements (1, 2, or 4 values), not named vectors.

- **`page_num` must be a single string or NULL.** Passing a numeric or
  vector will produce an error. Use glue syntax for dynamic page
  numbers: `page_num = "Page {i} of {n}"`.
