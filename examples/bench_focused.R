# examples/bench_focused.R
#
# Focused benchmark on the scenarios most likely to surface cache and
# device-lifecycle costs in tfl_table generation.
#
# Scenarios:
#   iris5p        tfl_table(iris) -> 5 pages.  Pagination-heavy.
#   big_df        500-row synthetic table.  Drawing-heavy across ~17 pages.
#   wrap_heavy    200-row x 5-col table with three narrative-text columns
#                 (hyphenated, multi-word).  Exercises the wrap pipeline
#                 plus per-cell clip-width measurement during drawing.
#   preview_iris  iris5p but rendered via export_tfl(..., preview = c(1, 2, 3))
#                 with an open pdf(NULL) device.  Measures whether the
#                 cache-through-drawing path benefits preview mode.
#   figure_multi  10-page ggplot list passed directly to export_tfl().
#                 Isolates the non-tfl_table per-page overhead so we can
#                 see whether Phase-1/2 device-lifecycle changes affect
#                 the figure path.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

set.seed(42L)

big_df <- data.frame(
  subject = sprintf("Subject %03d", 1:500),
  visit   = rep(c("Baseline", "Week 1", "Week 4", "Week 12"), length.out = 500),
  result  = round(rnorm(500, 100, 15), 1),
  flag    = sample(c("Y", "N", "?"), 500, replace = TRUE)
)

# 200-row wrap-heavy table.  The narrative columns contain hyphenated words
# and multi-word phrases so the wrap module's keep-before "-" break path is
# exercised on every row.  Numeric columns provide a control.
wrap_words <- c(
  "patient-reported", "treatment-emergent", "investigator-assessed",
  "adverse-event", "fully-resolved", "dose-reduction",
  "drug-related", "non-serious", "moderate-severity",
  "hospitalization-required", "follow-up"
)
make_wrap_text <- function() {
  paste(sample(wrap_words, 6L, replace = TRUE), collapse = " ")
}
wrap_heavy_df <- data.frame(
  subject     = sprintf("Subject %03d", 1:200),
  narrative_a = replicate(200, make_wrap_text()),
  narrative_b = replicate(200, make_wrap_text()),
  narrative_c = replicate(200, make_wrap_text()),
  score       = round(rnorm(200, 50, 10), 1),
  stringsAsFactors = FALSE
)

# 10 figure pages, each a small ggplot.  Mirrors a typical
# clinical-report-of-figures bundle.
fig_pages <- lapply(seq_len(10L), function(i) {
  list(content = ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) +
                   ggplot2::geom_point() +
                   ggplot2::ggtitle(sprintf("Figure %d", i)),
       header_left = sprintf("Figure %d.1", i))
})

scenarios <- list(
  iris5p = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(iris), file = out)
    unlink(out)
  },
  big_df = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(big_df), file = out)
    unlink(out)
  },
  wrap_heavy = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(wrap_heavy_df), file = out)
    unlink(out)
  },
  preview_iris = function() {
    # Preview mode needs a device open in the caller.  Use pdf(NULL) so
    # nothing is written to disk; close in on.exit so a crash mid-run
    # doesn't leak the device.
    grDevices::pdf(NULL, width = 11, height = 8.5)
    on.exit(grDevices::dev.off(), add = TRUE)
    export_tfl(tfl_table(iris), preview = c(1L, 2L, 3L))
  },
  figure_multi = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(fig_pages, file = out)
    unlink(out)
  }
)

for (name in names(scenarios)) {
  fn <- scenarios[[name]]
  invisible(fn())  # warmup
  bm <- bench::mark(fn(), iterations = 30L, check = FALSE,
                    filter_gc = FALSE, memory = FALSE)
  cat(sprintf("%-13s  min=%-9s  median=%-9s  iqr=%s  n=%d\n",
              name,
              format(bm$min),
              format(bm$median),
              format(bm$median - bm$min),
              bm$n_itr))
}
