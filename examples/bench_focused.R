# examples/bench_focused.R
#
# Focused benchmark on the scenarios most likely to show cross-page cache
# benefit: tfl_table(iris) (5 pages) and a 500-row synthetic table.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

big_df <- data.frame(
  subject = sprintf("Subject %03d", 1:500),
  visit   = rep(c("Baseline", "Week 1", "Week 4", "Week 12"), length.out = 500),
  result  = round(rnorm(500, 100, 15), 1),
  flag    = sample(c("Y", "N", "?"), 500, replace = TRUE)
)

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
  }
)

for (name in names(scenarios)) {
  fn <- scenarios[[name]]
  invisible(fn())  # warmup
  bm <- bench::mark(fn(), iterations = 30L, check = FALSE,
                    filter_gc = FALSE, memory = FALSE)
  cat(sprintf("%-10s  min=%-9s  median=%-9s  iqr=%s  n=%d\n",
              name,
              format(bm$min),
              format(bm$median),
              format(bm$median - bm$min),
              bm$n_itr))
}
