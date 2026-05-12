# examples/ggplot_stress.R
#
# The original crash happened inside the figure_multi Rprof block which was
# 20 invocations of an export that drew 5 ggplots each = 100 ggplot renders
# under Rprof sampling.  Phase 1 here is 5x that volume.  Phases 2/3 push the
# sampling and viewport-churn axes.
#
# Per ggplot, internally: ~200-500 grob ops + many push/pop viewport pairs.
# Phase 1 = 500 renders ~= 100k-250k grob ops in the ggplot rendering path.

suppressPackageStartupMessages({
  library(ggplot2)
})

one_export <- function() {
  pages <- lapply(1:5, function(i) {
    list(content = ggplot(mtcars, aes(hp, mpg)) + geom_point() +
                     ggtitle(sprintf("Page %d", i)),
         header_left = sprintf("Figure %d", i))
  })
  out <- tempfile(fileext = ".pdf")
  writetfl::export_tfl(pages, file = out)
  unlink(out)
}

devtools::load_all(quiet = TRUE)

cat("Phase 1: 100 figure-export invocations under Rprof@0.01\n")
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.01, line.profiling = TRUE, gc.profiling = TRUE)
t1 <- system.time({
  for (k in 1:100) one_export()
})
Rprof(NULL)
print(t1)
cat("  samples:", nrow(summaryRprof(prof)$by.self), "\n")

cat("\nPhase 2: 200 figure-export invocations under Rprof@0.001 (aggressive)\n")
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.001, line.profiling = TRUE, gc.profiling = TRUE)
t2 <- system.time({
  for (k in 1:200) one_export()
})
Rprof(NULL)
print(t2)
cat("  samples:", nrow(summaryRprof(prof)$by.self), "\n")

cat("\nPhase 3: 200 figure-export, no Rprof but force gc every 10 iters\n")
t3 <- system.time({
  for (k in 1:200) {
    one_export()
    if (k %% 10L == 0L) gc(verbose = FALSE)
  }
})
print(t3)

cat("\nNo segfault.\n")
