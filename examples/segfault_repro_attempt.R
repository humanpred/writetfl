# examples/segfault_repro_attempt.R
#
# **Status: could NOT reproduce the segfault despite multiple stress patterns.**
#
# The original crash:
#   $ Rscript examples/profile_writetfl.R
#   ... (core_small, core_wrap, core_paginate, figure_multi bench::mark output) ...
#   /usr/bin/bash: line 1: 671 Segmentation fault   Rscript examples/profile_writetfl.R
#   exit code 139 (= 128 + 11 = SIGSEGV)
#
# The crash landed after figure_multi's bench::mark had printed but before its
# Rprof block produced any "top 20" output -- so inside:
#
#   Rprof(prof_file, interval = 0.01, line.profiling = TRUE, gc.profiling = TRUE)
#   for (k in seq_len(20L)) figure_scenario()
#   Rprof(NULL)
#
# Reproduction attempts (none triggered the crash):
#   1. Run examples/profile_writetfl.R end-to-end x3      -> all exit 0
#   2. Phase 1-3 of this script x5                        -> all exit 0
#   3. Phase 1-3 with sampling interval reduced to 0.001  -> exit 0
#   4. examples/grob_stress.R    -> 50,000 textGrob+grobWidth calls per
#        phase x 5 phases (no device / pdf device / Rprof@0.02 / Rprof@0.001
#        / 50 device cycles), all exit 0.  Volume hypothesis ruled out at
#        10x the original scenario's count.
#   5. examples/ggplot_stress.R  -> 100 + 200 + 200 figure-exports (each
#        rendering 5 ggplots = up to 1000 internal grob ops apiece) with
#        Rprof@0.01, Rprof@0.001, and manual gc().  All exit 0.
#
# Hypothesised cause: a transient race between Rprof's signal-based sampling
# and grid's pdf-device teardown.  Each figure_scenario() opens a pdf device,
# draws 5 ggplots (which push/pop many viewports), and closes the device.
# Rprof sampling can land mid-teardown when device state is being mutated by
# grid C code.  A single mis-timed sample, combined with line.profiling
# walking the call stack into a half-finalised viewport tree, could plausibly
# produce SIGSEGV without R-level errors.  This is speculative -- without a
# native-stack crash dump we cannot confirm.
#
# What to do if it recurs:
#   * Set `_R_CRASH_REPORT_=1` (R >= 4.4) before running so the crash writes
#     /tmp/Rcrash.log with a native stack trace.
#   * Try `Rprof(interval = 0.02)` (less aggressive sampling) to see if the
#     crash rate drops.
#   * Try `Rprof(gc.profiling = FALSE)` to rule out gc-stack-walk + device
#     teardown interaction.
#   * Run figure_multi alone (no prior scenarios) under Rprof many times.
#     If it doesn't crash standalone, the crash depends on cross-scenario
#     state -- likely a leaked device handle or accumulated grid scratch
#     state.
#
# Until reproducible, no upstream report is actionable.

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

figure_scenario <- function() {
  pages <- lapply(seq_len(5L), function(i)
    list(content = ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) +
                     ggplot2::geom_point() +
                     ggplot2::ggtitle(sprintf("Page %d", i)),
         header_left = sprintf("Figure %d.1", i)))
  out <- tempfile(fileext = ".pdf")
  export_tfl(pages, file = out)
  unlink(out)
}

table_scenario <- function() {
  out <- tempfile(fileext = ".pdf")
  export_tfl(tfl_table(iris), file = out)
  unlink(out)
}

cat("Phase 1: warm-up the session (5 iris tables + 5 figure exports)\n")
for (i in 1:5)  table_scenario()
for (i in 1:5)  figure_scenario()

cat("Phase 2: 20-rep Rprof of figure_scenario (mirrors the harness block)\n")
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.01, line.profiling = TRUE, gc.profiling = TRUE)
for (k in seq_len(20L)) figure_scenario()
Rprof(NULL)
cat("  ok\n")

cat("Phase 3: aggressive sampling (interval = 0.001) on the same block\n")
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.001, line.profiling = TRUE, gc.profiling = TRUE)
for (k in seq_len(20L)) figure_scenario()
Rprof(NULL)
cat("  ok\n")

cat("\nNo segfault.\n")
