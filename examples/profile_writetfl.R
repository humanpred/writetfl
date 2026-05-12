# examples/profile_writetfl.R
#
# Profiling harness for writetfl.  Drives the package through representative
# inputs and reports where wall-clock time is spent.
#
# Usage (from the worktree root):
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" examples/profile_writetfl.R
#   Rscript examples/profile_writetfl.R --scenario core_wrap
#   Rscript examples/profile_writetfl.R --quick     # core scenarios only
#
# Scenarios:
#   core_small    head(mtcars, 20) -> tfl_table -> 1 page
#   core_wrap     issue35_clinical_df with wrap_balance="height"
#                   -> exercises wrap floor, water-fill, height-balance
#   core_paginate iris (150 rows) -> tfl_table -> multi-page row pagination
#   figure_multi  5-page ggplot list -> isolates export_tfl_page overhead
#   wrap_demos    source examples/wrap_demos.R (all 18 demos, aggregate)
#
# Output:
#   - bench::mark distribution per scenario (stdout)
#   - Top-20 self-time functions per scenario (stdout)
#   - .Rprof and profvis .html files in {tempdir()}/, paths printed
#   - results saved to {tempdir()}/profile_results_<timestamp>.rds

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

have_bench   <- requireNamespace("bench",   quietly = TRUE)
have_profvis <- requireNamespace("profvis", quietly = TRUE)

if (!have_bench)   message("[note] 'bench' not installed; using system.time() instead")
if (!have_profvis) message("[note] 'profvis' not installed; skipping HTML traces")

# ---------------------------------------------------------------------------
# CLI parsing
# ---------------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
opt_scenario <- NULL
opt_quick    <- FALSE
i <- 1L
while (i <= length(args)) {
  a <- args[[i]]
  if (a == "--scenario" && i < length(args)) {
    opt_scenario <- args[[i + 1L]]
    i <- i + 2L
  } else if (a == "--quick") {
    opt_quick <- TRUE
    i <- i + 1L
  } else {
    stop("Unknown arg: ", a)
  }
}

# ---------------------------------------------------------------------------
# Scenarios
# ---------------------------------------------------------------------------

scenario_core_small <- function() {
  out <- tempfile(fileext = ".pdf")
  tbl <- tfl_table(head(mtcars, 20))
  export_tfl(tbl, file = out)
  out
}

# Mirror of issue35_clinical_df from examples/wrap_demos.R:546-555.
# Three wrap-eligible string cols + two numeric cols, 10 rows.  With
# wrap_balance = "height" we exercise the full height-balance greedy search.
make_clinical_df <- function() {
  data.frame(
    ae_term      = rep(paste(rep("Headache mild moderate severe related",
                                 4), collapse = " "), 10),
    ae_action    = rep(paste(rep("Drug withdrawn temporarily",
                                 4), collapse = " "), 10),
    ae_notes     = rep(paste(rep("Patient continued safely",
                                 4), collapse = " "), 10),
    onset_day    = 1:10,
    duration_day = 11:20,
    stringsAsFactors = FALSE
  )
}

scenario_core_wrap <- function() {
  out <- tempfile(fileext = ".pdf")
  tbl <- tfl_table(make_clinical_df(),
                   col_split_strategy = "balanced",
                   wrap_balance       = "height")
  export_tfl(tbl, file = out,
             pg_width = 6, pg_height = 8.5,
             min_content_height = grid::unit(1, "inches"))
  out
}

scenario_core_paginate <- function() {
  out <- tempfile(fileext = ".pdf")
  tbl <- tfl_table(iris)
  export_tfl(tbl, file = out)
  out
}

scenario_figure_multi <- function() {
  pages <- lapply(seq_len(5L), function(i) {
    list(content = ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) +
                     ggplot2::geom_point() +
                     ggplot2::ggtitle(sprintf("Page %d", i)),
         header_left = sprintf("Figure %d.1", i))
  })
  out <- tempfile(fileext = ".pdf")
  export_tfl(pages, file = out)
  out
}

scenario_wrap_demos <- function() {
  # Source wrap_demos.R into an isolated env.  It writes PDFs to a temp
  # directory and prints progress.  We don't care about the outputs; we
  # care about the Rprof samples taken while it runs.
  src <- file.path("examples", "wrap_demos.R")
  if (!file.exists(src)) stop("wrap_demos.R not found at ", src)
  env <- new.env(parent = globalenv())
  sink_file <- tempfile(fileext = ".log")
  con <- file(sink_file, open = "wt")
  sink(con); sink(con, type = "message")
  on.exit({ sink(type = "message"); sink(); close(con) }, add = TRUE)
  sys.source(src, envir = env)
  invisible(NULL)
}

scenarios <- list(
  core_small    = scenario_core_small,
  core_wrap     = scenario_core_wrap,
  core_paginate = scenario_core_paginate,
  figure_multi  = scenario_figure_multi,
  wrap_demos    = scenario_wrap_demos
)

# bench iterations: wrap_demos runs all 18 demos (slow) so iterate once;
# core scenarios are fast so iterate 5 times to get a usable distribution.
iterations <- list(
  core_small    = 5L,
  core_wrap     = 5L,
  core_paginate = 5L,
  figure_multi  = 5L,
  wrap_demos    = 1L
)

# ---------------------------------------------------------------------------
# Scenario selection
# ---------------------------------------------------------------------------
if (!is.null(opt_scenario)) {
  if (!opt_scenario %in% names(scenarios)) {
    stop("--scenario must be one of: ", paste(names(scenarios), collapse = ", "))
  }
  selected <- opt_scenario
} else if (opt_quick) {
  selected <- c("core_small", "core_wrap", "core_paginate", "figure_multi")
} else {
  selected <- names(scenarios)
}

# ---------------------------------------------------------------------------
# Runner: bench + Rprof + profvis for one scenario
# ---------------------------------------------------------------------------
run_scenario <- function(name) {
  fn   <- scenarios[[name]]
  iter <- iterations[[name]]
  cat(sprintf("\n================ scenario: %s (%d iterations) ================\n",
              name, iter))

  # Warm-up: makes timing more representative by paying first-touch costs
  # (devtools::load_all, grid namespace, etc.) outside the timed window.
  invisible(fn())

  out <- list(name = name)

  # 1. Wall-clock distribution
  if (have_bench) {
    bm <- bench::mark(fn(),
                      iterations = iter,
                      check      = FALSE,
                      filter_gc  = FALSE,
                      memory     = FALSE)
    cat("\n-- bench::mark --\n")
    print(bm[, c("min", "median", "mem_alloc", "n_itr", "n_gc")])
    out$bench <- bm
  } else {
    t <- system.time(for (k in seq_len(iter)) fn())
    cat("\n-- system.time (total over", iter, "iter) --\n")
    print(t)
    out$system_time <- t
  }

  # 2. Rprof samples.  Save under examples/profile_output/ so files survive
  # past the Rscript session's tempdir cleanup.
  stable_dir <- file.path("examples", "profile_output")
  dir.create(stable_dir, showWarnings = FALSE, recursive = TRUE)
  prof_file <- file.path(stable_dir,
                         sprintf("profile_%s_%s.Rprof", name,
                                 format(Sys.time(), "%Y%m%d_%H%M%S")))
  # Loop the timed run so Rprof gets enough samples on fast scenarios.
  # Target ~5 s of profiling per scenario; wrap_demos already gets ~10 s so
  # skip the repeat there.
  reps <- if (name == "wrap_demos") 1L else 20L
  Rprof(prof_file, interval = 0.01, line.profiling = TRUE,
        gc.profiling = TRUE)
  for (k in seq_len(reps)) fn()
  Rprof(NULL)
  s <- summaryRprof(prof_file, lines = "both")
  out$rprof_path    <- prof_file
  out$rprof_summary <- s
  cat("\n-- top 20 by self.pct (Rprof) --\n")
  if (nrow(s$by.self) > 0L) {
    print(utils::head(s$by.self[, c("self.time", "self.pct", "total.time",
                                    "total.pct")], 20L))
  } else {
    cat("(no samples — scenario completed faster than profiling interval)\n")
  }
  cat("\n-- top 15 writetfl source lines by self.pct --\n")
  bs <- s$by.self
  ix <- grep("^[a-z_]+\\.R#", rownames(bs))
  if (length(ix) > 0L) {
    sub <- bs[ix, c("self.time", "self.pct", "total.time", "total.pct"),
              drop = FALSE]
    print(utils::head(sub[order(-sub$self.pct), ], 15L))
  } else {
    cat("(no source-line samples)\n")
  }
  cat("Rprof file:", prof_file, "\n")

  # 3. profvis HTML (optional)
  if (have_profvis) {
    html_file <- tempfile(pattern = paste0("profvis_", name, "_"),
                          fileext = ".html")
    pv <- profvis::profvis(fn(), interval = 0.01)
    htmlwidgets::saveWidget(pv, html_file, selfcontained = TRUE)
    out$profvis_path <- html_file
    cat("profvis HTML:", html_file, "\n")
  }

  out
}

# ---------------------------------------------------------------------------
# Execute
# ---------------------------------------------------------------------------
results <- list()
for (name in selected) {
  results[[name]] <- tryCatch(run_scenario(name),
                              error = function(e) {
                                cat("[FAIL]", name, ":", conditionMessage(e), "\n")
                                list(name = name, error = conditionMessage(e))
                              })
}

# ---------------------------------------------------------------------------
# Summary table
# ---------------------------------------------------------------------------
cat("\n================ wall-clock summary ================\n")
for (name in selected) {
  r <- results[[name]]
  if (!is.null(r$bench)) {
    cat(sprintf("  %-15s  median = %s  (n = %d)\n",
                name,
                format(r$bench$median),
                r$bench$n_itr))
  } else if (!is.null(r$system_time)) {
    cat(sprintf("  %-15s  elapsed = %.3f s\n",
                name, r$system_time[["elapsed"]]))
  } else {
    cat(sprintf("  %-15s  [error]\n", name))
  }
}

# Save raw results for follow-up analysis
ts  <- format(Sys.time(), "%Y%m%d_%H%M%S")
rds <- file.path(tempdir(), sprintf("profile_results_%s.rds", ts))
saveRDS(results, file = rds)
cat("\nResults saved:", rds, "\n")
