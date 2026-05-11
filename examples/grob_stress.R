# examples/grob_stress.R
#
# Stress test: many rapid grob-width measurements under Rprof, testing the
# hypothesis that the SIGSEGV in profile_writetfl.R was a memory/race issue
# in grid triggered by sheer measurement volume rather than by any specific
# writetfl code path.
#
# Each phase pushes a different axis:
#   1. Many measurements, no device, no Rprof -- baseline
#   2. Many measurements, pdf device open, no Rprof
#   3. Many measurements, pdf device open, Rprof at default 0.02 interval
#   4. Many measurements, pdf device open, Rprof at aggressive 0.001 interval
#   5. Many measurements, repeated device open/close cycles, Rprof active
#
# Volume target: ~50k textGrob+grobWidth calls per phase, roughly an order of
# magnitude more than profile_writetfl.R's figure_multi block produces.

N <- 50000L

# Vary the strings so grid cannot incidentally short-circuit on identity.
make_strings <- function(n) {
  pool <- c(
    "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
    "alpha beta gamma", "delta epsilon zeta", "eta theta iota",
    "1.234", "5.678", "9.012", "NA",
    "Subject 001", "Subject 002", "Subject 003",
    "Headache mild", "Drug withdrawn", "Patient continued safely"
  )
  sample(pool, n, replace = TRUE)
}

measure_block <- function(strings, gp) {
  for (s in strings) {
    grid::convertWidth(grid::grobWidth(grid::textGrob(s, gp = gp)),
                       "inches", valueOnly = TRUE)
  }
}

gp <- grid::gpar(fontfamily = "", fontface = "plain",
                 fontsize = 10, lineheight = 1.0)
strs <- make_strings(N)

cat("Phase 1: ", N, " grob measurements, no device, no Rprof\n", sep = "")
t1 <- system.time(measure_block(strs, gp))
print(t1)

cat("\nPhase 2: ", N, " measurements, pdf device open, no Rprof\n", sep = "")
pdf_file <- tempfile(fileext = ".pdf")
grDevices::pdf(pdf_file, width = 7, height = 5)
grid::pushViewport(grid::viewport())
t2 <- system.time(measure_block(strs, gp))
grid::popViewport()
grDevices::dev.off()
unlink(pdf_file)
print(t2)

cat("\nPhase 3: ", N, " measurements, pdf device, Rprof @ 0.02s interval\n",
    sep = "")
pdf_file <- tempfile(fileext = ".pdf")
grDevices::pdf(pdf_file, width = 7, height = 5)
grid::pushViewport(grid::viewport())
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.02, line.profiling = TRUE, gc.profiling = TRUE)
t3 <- system.time(measure_block(strs, gp))
Rprof(NULL)
grid::popViewport()
grDevices::dev.off()
unlink(pdf_file)
print(t3)
cat("  Rprof samples:", nrow(summaryRprof(prof)$by.self), "rows\n")

cat("\nPhase 4: ", N, " measurements, pdf device, Rprof @ 0.001s interval\n",
    sep = "")
pdf_file <- tempfile(fileext = ".pdf")
grDevices::pdf(pdf_file, width = 7, height = 5)
grid::pushViewport(grid::viewport())
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.001, line.profiling = TRUE, gc.profiling = TRUE)
t4 <- system.time(measure_block(strs, gp))
Rprof(NULL)
grid::popViewport()
grDevices::dev.off()
unlink(pdf_file)
print(t4)
cat("  Rprof samples:", nrow(summaryRprof(prof)$by.self), "rows\n")

cat("\nPhase 5: repeated open/close + measure cycles, Rprof @ 0.001s\n")
prof <- tempfile(fileext = ".Rprof")
Rprof(prof, interval = 0.001, line.profiling = TRUE, gc.profiling = TRUE)
t5 <- system.time({
  for (cyc in 1:50) {
    pdf_file <- tempfile(fileext = ".pdf")
    grDevices::pdf(pdf_file, width = 7, height = 5)
    grid::pushViewport(grid::viewport())
    measure_block(strs[seq_len(N / 50)], gp)
    grid::popViewport()
    grDevices::dev.off()
    unlink(pdf_file)
  }
})
Rprof(NULL)
print(t5)
cat("  Rprof samples:", nrow(summaryRprof(prof)$by.self), "rows\n")

cat("\nNo segfault.\n")
