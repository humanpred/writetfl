# examples/bench_compare.R
#
# Standalone benchmark used to compare two code versions side-by-side.
# Run with `git stash` flipping the optimisation on/off so both timings come
# from the same R session settings.
#
# Usage:
#   Rscript examples/bench_compare.R              # all scenarios
#   Rscript examples/bench_compare.R core_wrap    # one scenario

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

args <- commandArgs(trailingOnly = TRUE)
selected <- if (length(args) > 0L) args else
  c("core_small", "core_wrap", "core_paginate", "figure_multi", "wrap_demos")

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

scenarios <- list(
  core_small = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(head(mtcars, 20)), file = out)
    unlink(out)
  },
  core_wrap = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(make_clinical_df(),
                         col_split_strategy = "balanced",
                         wrap_balance       = "height"),
               file = out, pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
    unlink(out)
  },
  core_paginate = function() {
    out <- tempfile(fileext = ".pdf")
    export_tfl(tfl_table(iris), file = out)
    unlink(out)
  },
  figure_multi = function() {
    pages <- lapply(seq_len(5L), function(i)
      list(content = ggplot2::ggplot(mtcars, ggplot2::aes(hp, mpg)) +
             ggplot2::geom_point(),
           header_left = sprintf("Figure %d.1", i)))
    out <- tempfile(fileext = ".pdf")
    export_tfl(pages, file = out)
    unlink(out)
  },
  wrap_demos = function() {
    src <- file.path("examples", "wrap_demos.R")
    env <- new.env(parent = globalenv())
    sf  <- tempfile()
    con <- file(sf, open = "wt")
    sink(con); sink(con, type = "message")
    on.exit({ sink(type = "message"); sink(); close(con); unlink(sf) }, add = TRUE)
    sys.source(src, envir = env)
  }
)

iter <- list(core_small = 15L, core_wrap = 15L, core_paginate = 15L,
             figure_multi = 15L, wrap_demos = 3L)

for (name in selected) {
  fn <- scenarios[[name]]
  invisible(fn())  # warmup
  bm <- bench::mark(fn(), iterations = iter[[name]], check = FALSE,
                    filter_gc = FALSE, memory = FALSE)
  cat(sprintf("%-15s  min=%-9s  median=%-9s  mean=%-9s  n=%d\n",
              name,
              format(bm$min),
              format(bm$median),
              format(bm$mean),
              bm$n_itr))
}
