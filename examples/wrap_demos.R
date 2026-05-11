# examples/wrap_demos.R
#
# Hands-on demonstration of every behaviour in the column word-wrap module
# added for issue #28.  Generates one PDF per scenario into a temporary
# directory plus a README.md summarising what each PDF shows and any
# captured warning text (for the row-overflow guard demo).
#
# Run from the worktree root:
#   "C:/Program Files/R/R-4.5.2/bin/Rscript.exe" examples/wrap_demos.R

suppressPackageStartupMessages({
  devtools::load_all(quiet = TRUE)
})

# ---------------------------------------------------------------------------
# Output directory
# ---------------------------------------------------------------------------

# Place under the OS user-temp dir so the directory persists after this
# Rscript session exits (R's session tempdir() is wiped on shutdown).
.persistent_temp <- function() {
  for (v in c("TEMP", "TMP", "TMPDIR")) {
    val <- Sys.getenv(v, unset = "")
    if (nzchar(val) && dir.exists(val)) return(val)
  }
  tempdir()
}
out_dir <- file.path(.persistent_temp(),
                     paste0("writetfl_wrap_demos_",
                            format(Sys.time(), "%Y%m%d_%H%M%S")))
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
readme  <- file.path(out_dir, "wrap_demos_README.md")
cat("# wrap module demos (issue #28)\n\n",
    "_Generated:_ ", format(Sys.time()), "\n\n",
    "Each PDF below demonstrates one configuration of the new word-wrap ",
    "module on the same family of inputs.\n\n",
    file = readme, sep = "")

# Helper: append a section to the README and run a generator that may
# also surface warnings or errors that we want recorded next to the PDF.
add_section <- function(file, title, blurb, generator) {
  cat("## ", file, "\n\n", title, "\n\n", blurb, "\n\n",
      file = readme, append = TRUE, sep = "")
  msgs <- character(0L)
  res  <- tryCatch(
    withCallingHandlers(
      generator(),
      warning = function(w) {
        msgs <<- c(msgs, paste0("WARNING: ", conditionMessage(w)))
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) {
      msgs <<- c(msgs, paste0("ERROR: ", conditionMessage(e)))
      NULL
    }
  )
  if (length(msgs) > 0L) {
    cat("```\n", paste(msgs, collapse = "\n"), "\n```\n\n",
        file = readme, append = TRUE, sep = "")
  }
  invisible(res)
}

p <- function(name) file.path(out_dir, name)

# ---------------------------------------------------------------------------
# Common test data
# ---------------------------------------------------------------------------

# Sized so each column individually fits a 6-inch page when not wrapped
# (so the page-column-split path can succeed) but the two together exceed
# the content area (so wrapping or splitting is needed).
wide_df <- data.frame(
  alpha = rep(paste(rep("alpha", 7), collapse = " "), 3),
  bravo = rep(paste(rep("bravo", 7), collapse = " "), 3),
  count = c(101L, 202L, 303L)
)

# A column whose contents only break on "-".
hyphen_df <- data.frame(
  term = c("placebo-controlled-extension",
           "double-blind-randomised-trial",
           "open-label-rollover-study"),
  n    = c(120L, 88L, 64L)
)

path_df <- data.frame(
  path = c("/var/log/system/messages",
           "/etc/cron.daily/backup-rotate",
           "/usr/share/doc/writetfl/NEWS.md"),
  size = c(1024L, 8456L, 612L)
)

medclass_df <- data.frame(
  `Concomitant Medication Class` = c("Statin", "ACE inhibitor",
                                       "Beta blocker"),
  n = c(45L, 78L, 22L),
  check.names = FALSE
)

# Three escalating-width string columns to show water-fill balance.
balance_df <- data.frame(
  short  = rep(paste(rep("aa bb", 4), collapse = " "), 3),
  middle = rep(paste(rep("aa bb cc dd", 4), collapse = " "), 3),
  longer = rep(paste(rep("aa bb cc dd ee ff gg hh", 4), collapse = " "), 3)
)

# ---------------------------------------------------------------------------
# 01 — wrap off, allow_col_split = FALSE -> error
# ---------------------------------------------------------------------------

add_section(
  "01_off_overflows.pdf",
  "Wrap off + page-column-split off on a too-wide table",
  paste0("With `wrap_cols = FALSE` and `allow_col_split = FALSE` the ",
         "package signals a clear width-overflow error rather than letting ",
         "the table fall off the page.  No PDF is produced; the captured ",
         "error message is below."),
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = FALSE, allow_col_split = FALSE)
    export_tfl(tbl, file = p("01_off_overflows.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 02 — wrap_cols = "auto" (the new default) wraps the string cols
# ---------------------------------------------------------------------------

add_section(
  "02_auto_default.pdf",
  "Default `wrap_cols = \"auto\"` auto-detects breakable columns",
  paste0("Same data as 01.  No `wrap_cols` argument means `\"auto\"` is in ",
         "force: the two `alpha` / `bravo` string columns auto-wrap, the ",
         "numeric `count` column is left at its natural width.  The whole ",
         "table now fits one page width."),
  function() {
    tbl <- tfl_table(wide_df, allow_col_split = FALSE)
    export_tfl(tbl, file = p("02_auto_default.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 03 — wrap_cols = TRUE: identical visual outcome but explicit
# ---------------------------------------------------------------------------

add_section(
  "03_wrap_true_explicit.pdf",
  "`wrap_cols = TRUE` (all data columns eligible)",
  paste0("Marks every non-group column as wrap-eligible regardless of ",
         "content.  For this data the visual outcome matches 02 because ",
         "the numeric column does not contain a break character; the ",
         "wrap algorithm leaves it alone."),
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = TRUE, allow_col_split = FALSE)
    export_tfl(tbl, file = p("03_wrap_true_explicit.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 04 — wrap only named columns
# ---------------------------------------------------------------------------

add_section(
  "04_wrap_named_cols.pdf",
  "`wrap_cols = c(\"alpha\")` - only `alpha` may wrap",
  paste0("Only the `alpha` column is wrap-eligible; `bravo` keeps its full ",
         "natural width.  Because `alpha` alone has to absorb the entire ",
         "page-width deficit, it ends up visibly narrower (more wrapped ",
         "lines per cell) than in 02 where both string columns shared the ",
         "burden.  The whole table still fits on a single page here ",
         "because the deficit is small enough that `alpha` does not hit ",
         "its longest-token floor."),
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = c("alpha"))
    export_tfl(tbl, file = p("04_wrap_named_cols.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 05 — per-colspec override: opt one column out of "auto"
# ---------------------------------------------------------------------------

add_section(
  "05_per_colspec_override.pdf",
  "Per-column override via `tfl_colspec(wrap = FALSE)`",
  paste0("`wrap_cols = \"auto\"` would normally mark both string columns ",
         "wrap-eligible; the per-column spec for `bravo` says \"no, never ",
         "wrap me\".  So only `alpha` wraps - same shape of result as 04 ",
         "but the mechanism is different.  The point: `tfl_colspec(wrap = ",
         "FALSE)` is a hard veto that beats the table-level `wrap_cols`."),
  function() {
    tbl <- tfl_table(
      wide_df,
      cols = list(tfl_colspec("bravo", wrap = FALSE))
    )
    export_tfl(tbl, file = p("05_per_colspec_override.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 06 — keep_before = "-" on a hyphenated column
# ---------------------------------------------------------------------------

add_section(
  "06_keep_before_dash.pdf",
  "`wrap_breaks(keep_before = \"-\")` breaks AFTER hyphens",
  paste0("Each row of the `term` column is one long hyphenated phrase with ",
         "no spaces.  Default whitespace-only `wrap_breaks` cannot break it ",
         "at all; with `keep_before = \"-\"` the wrap module breaks after ",
         "each `-` and keeps the `-` on the upper line."),
  function() {
    tbl <- tfl_table(
      hyphen_df,
      wrap_breaks = wrap_breaks(drop = " ", keep_before = "-"),
      cols = list(tfl_colspec("term", width = grid::unit(1.0, "inches"),
                              wrap = TRUE))
    )
    export_tfl(tbl, file = p("06_keep_before_dash.pdf"),
               pg_width = 5, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 07 — keep_before = c("-", "/") on a path-like column
# ---------------------------------------------------------------------------

add_section(
  "07_keep_before_slash.pdf",
  "`wrap_breaks(keep_before = c(\"-\", \"/\"))` for path-like content",
  paste0("Demonstrates that multiple `keep_before` characters work ",
         "together.  Lines may end in `/` or `-`; either way the next ",
         "character starts a new line."),
  function() {
    tbl <- tfl_table(
      path_df,
      wrap_breaks = wrap_breaks(drop = " ", keep_before = c("-", "/")),
      cols = list(tfl_colspec("path", width = grid::unit(1.0, "inches"),
                              wrap = TRUE))
    )
    export_tfl(tbl, file = p("07_keep_before_slash.pdf"),
               pg_width = 5, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 08 — header wraps when the column is narrow
# ---------------------------------------------------------------------------

add_section(
  "08_header_wraps.pdf",
  "Header text auto-wraps when the column is wrap-eligible",
  paste0("The header `Concomitant Medication Class` is much wider than the ",
         "1.3-inch column but each individual word fits.  The wrap module ",
         "reflows the header onto three lines (`Concomitant` / ",
         "`Medication` / `Class`) instead of letting it overflow.  The ",
         "column width is chosen to be wider than the longest single ",
         "word in bold so wrap actually has somewhere to break - a ",
         "narrower column would hit the longest-unbreakable-token floor ",
         "and the bold-aware width measurement would refuse to undersize."),
  function() {
    tbl <- tfl_table(
      medclass_df,
      cols = list(tfl_colspec("Concomitant Medication Class",
                              width = grid::unit(1.3, "inches"),
                              wrap  = TRUE))
    )
    export_tfl(tbl, file = p("08_header_wraps.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 09 — water-from-top balance: shrink widest, then equal pair
# ---------------------------------------------------------------------------

add_section(
  "09_water_fill_balance.pdf",
  "Water-from-top algorithm: widest first, then equal pair",
  paste0("Three escalating-width string columns.  The wrap module shrinks ",
         "the widest column first; once it matches the next-widest, the ",
         "two shrink together.  All three contribute fairly to absorbing ",
         "the page-width deficit."),
  function() {
    tbl <- tfl_table(balance_df, allow_col_split = FALSE)
    export_tfl(tbl, file = p("09_water_fill_balance.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 10 — column floor = longest unbreakable token
# ---------------------------------------------------------------------------

add_section(
  "10_floor_unbreakable.pdf",
  "Wrap floor = widest unbreakable token",
  paste0("The `drug` column contains a single long token with no break ",
         "characters.  No matter how aggressively the algorithm narrows ",
         "the column, it cannot drop below the rendered width of that ",
         "token.  Notice the `drug` column ends up *wider* than ",
         "`min_col_width` because the token sets the floor."),
  function() {
    df <- data.frame(
      drug = rep("Cyclosporine_Microemulsion_Capsules_100mg", 3),
      n    = 1:3,
      stringsAsFactors = FALSE
    )
    tbl <- tfl_table(df,
                     min_col_width = grid::unit(0.2, "inches"),
                     allow_col_split = FALSE)
    export_tfl(tbl, file = p("10_floor_unbreakable.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 11 — row-overflow guard: error vs warn
# ---------------------------------------------------------------------------

add_section(
  "11_row_overflow_error.pdf",
  "Row-overflow guard fires when a wrapped cell exceeds page height",
  paste0("A single cell containing a 6,500-character essay forced into a ",
         "0.8-inch column wraps to a height larger than the page.  The ",
         "fail-safe in `paginate_rows()` rejects this with a clear error ",
         "(no PDF written).  See the captured stderr below."),
  function() {
    long_essay <- paste(rep(paste(rep("aa bb cc dd ee ff", 3),
                                   collapse = " "), 120),
                         collapse = " ")
    df  <- data.frame(notes = long_essay, stringsAsFactors = FALSE)
    tbl <- tfl_table(df,
                     cols = list(tfl_colspec("notes",
                                              width = grid::unit(0.8, "inches"),
                                              wrap = TRUE)))
    export_tfl(tbl, file = p("11_row_overflow_error.pdf"),
               pg_width = 4, pg_height = 8.5,
               min_content_height = grid::unit(0.5, "inches"))
  }
)

add_section(
  "11b_row_overflow_warn.pdf",
  "Same input under `overflow_action = \"warn\"`",
  paste0("Identical input to 11 but the user opts in to `overflow_action ",
         "= \"warn\"`.  The PDF is produced (with the over-tall row clipped ",
         "by the page) and the warning is captured.  Use this only as a ",
         "diagnostic - the output is still wrong; the input needs to ",
         "change."),
  function() {
    long_essay <- paste(rep(paste(rep("aa bb cc dd ee ff", 3),
                                   collapse = " "), 120),
                         collapse = " ")
    df  <- data.frame(notes = long_essay, stringsAsFactors = FALSE)
    tbl <- tfl_table(df,
                     cols = list(tfl_colspec("notes",
                                              width = grid::unit(0.8, "inches"),
                                              wrap = TRUE)))
    export_tfl(tbl, file = p("11b_row_overflow_warn.pdf"),
               pg_width = 4, pg_height = 8.5,
               min_content_height = grid::unit(0.5, "inches"),
               overflow_action = "warn")
  }
)

# ---------------------------------------------------------------------------
# 12 — text-wrap vs page-column-split independence (composable)
# ---------------------------------------------------------------------------

add_section(
  "12_text_wrap_only.pdf",
  "Text-wrap on, page-split off (composability part 1)",
  "Wide table.  `wrap_cols = TRUE`, `allow_col_split = FALSE`.  Text-wrap alone resolves it.",
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = TRUE, allow_col_split = FALSE)
    export_tfl(tbl, file = p("12_text_wrap_only.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

add_section(
  "12_page_split_only.pdf",
  "Text-wrap off, page-split on (composability part 2)",
  "Wide table.  `wrap_cols = FALSE`, `allow_col_split = TRUE`.  Page-column-split alone resolves it.",
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = FALSE, allow_col_split = TRUE)
    export_tfl(tbl, file = p("12_page_split_only.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

add_section(
  "12_both.pdf",
  "Text-wrap and page-split both on (composability part 3)",
  paste0("Wide table.  Both `wrap_cols = TRUE` and `allow_col_split = TRUE`.  ",
         "Text-wrap runs first; the page-split fallback runs only if ",
         "wrapping does not fit everything.  The two are independent ",
         "concepts and freely composable."),
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = TRUE, allow_col_split = TRUE)
    export_tfl(tbl, file = p("12_both.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ---------------------------------------------------------------------------
# 13 — module fully disabled
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 14 - height-balance opt-in vs default width-balance
# ---------------------------------------------------------------------------

# notes_a (24 alpha tokens) is dense; notes_b (5 alpha tokens) is sparse.
# Water-fill puts both columns at near-equal widths.  At those widths
# notes_a wraps to one more line than notes_b, and that one extra line
# applied to every row makes the table spill across two pages.
asym_df <- data.frame(
  notes_a = rep(paste(rep("alpha", 24), collapse = " "), 7),
  notes_b = rep(paste(rep("alpha", 5),  collapse = " "), 7)
)

add_section(
  "14_balance_width.pdf",
  "Default `wrap_balance = \"width\"` on asymmetric content",
  paste0("Water-fill makes the two wrap-eligible columns roughly equal in ",
         "width.  notes_a (24 dense tokens) wraps to 5 lines per cell; ",
         "notes_b (5 dense tokens) wraps to 1 line.  The row height is ",
         "5 lines and the table needs two pages."),
  function() {
    tbl <- tfl_table(asym_df, allow_col_split = FALSE,
                     wrap_balance = "width")
    export_tfl(tbl, file = p("14_balance_width.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

add_section(
  "14_balance_height.pdf",
  "Opt-in `wrap_balance = \"height\"` on the same input",
  paste0("Same data and page as 14_balance_width.  The opt-in height-",
         "balance pass shifts width from notes_b (which had only 5 tokens ",
         "per cell - its 1 line of content barely needed half its width) ",
         "to notes_a, dropping notes_a from 5 lines to 4 while notes_b ",
         "becomes 2 lines.  Total table height drops by ~20%, and the ",
         "table now fits on a single page."),
  function() {
    tbl <- tfl_table(asym_df, allow_col_split = FALSE,
                     wrap_balance = "height")
    export_tfl(tbl, file = p("14_balance_height.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

add_section(
  "13_disabled_module.pdf",
  "Module disabled with `wrap_cols = FALSE`",
  paste0("`wrap_cols = FALSE` is the escape hatch.  No text-wrap is ",
         "attempted; the page-column-split fallback handles too-wide ",
         "tables.  Visually identical to pre-PR behaviour."),
  function() {
    tbl <- tfl_table(wide_df, wrap_cols = FALSE)
    export_tfl(tbl, file = p("13_disabled_module.pdf"),
               pg_width = 6, pg_height = 8.5,
               min_content_height = grid::unit(1, "inches"))
  }
)

# ===========================================================================
# Issue #35 - col_split_strategy comparison
# ===========================================================================
# Each scenario renders TWICE on the same input - once with the legacy
# "wrap_first" strategy and once with the new default "balanced".  Compare
# the *_wrap_first.pdf and *_balanced.pdf pages side-by-side to see whether
# the new strategy actually delivers wider per-page columns.

cat("\n## col_split_strategy comparison (issue #35)\n\n",
    "The PDFs below are paired: open the _wrap_first and _balanced ",
    "versions of each scenario side-by-side and compare per-page column ",
    "widths.  Under the new default the columns on each split page receive ",
    "that page's actual horizontal slack rather than the cross-page",
    "minimum.\n\n",
    file = readme, append = TRUE, sep = "")

# Scenario 15: 4 columns, two wrap-eligible string + two unbreakable.
# Page 1 = {a, b, c}, page 2 = {d}.  Under wrap_first, a + b are crushed
# to their floor because the whole-table water-fill has to keep room for
# d (which ends up on page 2 anyway).  Under balanced, a + b share
# page 1's slack with c and end up much wider.
issue35_asym_df <- data.frame(
  alpha   = rep(paste(rep("alpha", 8), collapse = " "), 4),
  bravo   = rep(paste(rep("bravo", 8), collapse = " "), 4),
  short_c = rep("unbreak_one_token_here", 4),
  long_d  = rep("another_long_token_unbreakable", 4),
  stringsAsFactors = FALSE
)

for (strat in c("wrap_first", "balanced")) {
  local({
    s <- strat
    add_section(
      sprintf("15_split_with_unbreakables_%s.pdf", s),
      sprintf("Asymmetric mix - col_split_strategy = \"%s\"", s),
      sprintf(paste0("4 columns: two wrap-eligible strings (alpha, bravo) ",
                     "and two single-token columns (short_c, long_d).  Page ",
                     "1 receives {alpha, bravo, short_c}; page 2 receives ",
                     "{long_d} alone.  Under col_split_strategy = \"%s\".  ",
                     "Look at how wide alpha and bravo are on page 1: under ",
                     "\"wrap_first\" they are crushed to ~0.6 inches, under ",
                     "\"balanced\" they are ~1.4 inches."), s),
      function() {
        tbl <- tfl_table(issue35_asym_df, col_split_strategy = s)
        export_tfl(tbl,
                   file = p(sprintf("15_split_with_unbreakables_%s.pdf", s)),
                   pg_width = 6, pg_height = 8.5,
                   min_content_height = grid::unit(1, "inches"))
      }
    )
  })
}

# Scenario 16: 3 wrap-eligible cols + 2 numeric cols, multi-page table.
# Demonstrates that under "balanced" each page's wrap-eligible columns
# water-fill into that page's slack.
issue35_clinical_df <- data.frame(
  ae_term      = rep(paste(rep("Headache mild moderate severe related",
                                4), collapse = " "), 10),
  ae_action    = rep(paste(rep("Drug withdrawn temporarily",
                                4), collapse = " "), 10),
  ae_notes     = rep(paste(rep("Patient continued safely",
                                4), collapse = " "), 10),
  onset_day    = 1:10,
  duration_day = 11:20
)

for (strat in c("wrap_first", "balanced")) {
  local({
    s <- strat
    add_section(
      sprintf("16_clinical_three_wrap_cols_%s.pdf", s),
      sprintf("3 wrap-eligible string cols + 2 numerics - col_split_strategy = \"%s\"", s),
      sprintf(paste0("A clinical listing with three free-text columns and ",
                     "two narrow numeric columns.  Total natural width ",
                     "exceeds one page so the table page-splits.  Under ",
                     "\"%s\".  Open both versions side-by-side: \"balanced\" ",
                     "should give each free-text column substantially more ",
                     "width per page than \"wrap_first\"."), s),
      function() {
        tbl <- tfl_table(issue35_clinical_df, col_split_strategy = s)
        export_tfl(tbl,
                   file = p(sprintf("16_clinical_three_wrap_cols_%s.pdf", s)),
                   pg_width = 6, pg_height = 8.5,
                   min_content_height = grid::unit(1, "inches"))
      }
    )
  })
}

# Scenario 17: single-page table (sum(natural) <= content_width).  Both
# strategies should produce identical output.
issue35_small_df <- data.frame(
  arm       = c("Active", "Placebo"),
  n         = c(120L, 118L),
  responder = c(68L, 31L),
  stringsAsFactors = FALSE
)

for (strat in c("wrap_first", "balanced")) {
  local({
    s <- strat
    add_section(
      sprintf("17_fits_one_page_%s.pdf", s),
      sprintf("Table that fits one page - col_split_strategy = \"%s\"", s),
      sprintf(paste0("Sanity check: a table that fits comfortably on one ",
                     "page width should produce identical output under both ",
                     "strategies (no wrap or split needed).  ",
                     "col_split_strategy = \"%s\"."), s),
      function() {
        tbl <- tfl_table(issue35_small_df, col_split_strategy = s)
        export_tfl(tbl,
                   file = p(sprintf("17_fits_one_page_%s.pdf", s)),
                   pg_width = 6, pg_height = 8.5,
                   min_content_height = grid::unit(1, "inches"))
      }
    )
  })
}

# Scenario 18: row-overflow recovery via row_overflow_max_retries.  A
# moderately-sized cell wrapped into a deliberately narrow column would
# normally overflow the page; the balanced strategy's retry loop should
# widen the offending column and recover.  Sized so the default 5 retries
# (each + 0.25") arrive at a column wide enough to fit the cell within
# the page content height.
issue35_overflow_df <- data.frame(
  note  = rep(paste(rep("alpha beta gamma delta",
                         5), collapse = " "), 3),
  small = rep("x", 3),
  stringsAsFactors = FALSE
)

add_section(
  "18_row_overflow_retry_disabled.pdf",
  "Row-overflow with retry disabled (row_overflow_max_retries = 0)",
  paste0("Same input as 18_..._enabled.pdf below but with the retry loop ",
         "disabled.  The first row's wrapped height exceeds the page so ",
         "the standard error fires (no PDF produced).  See captured stderr ",
         "below."),
  function() {
    tbl <- tfl_table(
      issue35_overflow_df,
      cols = list(tfl_colspec("note", width = grid::unit(0.5, "inches"),
                              wrap = TRUE)),
      row_overflow_max_retries = 0L
    )
    export_tfl(tbl, file = p("18_row_overflow_retry_disabled.pdf"),
               pg_width = 5, pg_height = 5,
               min_content_height = grid::unit(0.5, "inches"))
  }
)

add_section(
  "18_row_overflow_retry_enabled.pdf",
  "Row-overflow with retry enabled (default 5 retries)",
  paste0("Same input.  Under the default `row_overflow_max_retries = 5L`, ",
         "the balanced strategy raises the offending column's minimum ",
         "width by 0.25 inches and re-runs the width pipeline.  After ",
         "enough retries the column is wide enough that its cell wraps ",
         "to a height that fits on the page, and the PDF renders."),
  function() {
    tbl <- tfl_table(
      issue35_overflow_df,
      cols = list(tfl_colspec("note", width = grid::unit(0.5, "inches"),
                              wrap = TRUE))
      # row_overflow_max_retries defaults to 5L
    )
    export_tfl(tbl, file = p("18_row_overflow_retry_enabled.pdf"),
               pg_width = 5, pg_height = 5,
               min_content_height = grid::unit(0.5, "inches"))
  }
)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

cat("Demos written to:\n  ", normalizePath(out_dir, mustWork = FALSE), "\n",
    sep = "")
cat("Open the README at:\n  ",
    normalizePath(readme, mustWork = FALSE), "\n", sep = "")
cat("\nOn Windows:  start \"\" \"", normalizePath(out_dir, mustWork = FALSE),
    "\"\n", sep = "")
