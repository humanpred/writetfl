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
         "0.8-inch column.  The wrap module reflows the header onto ",
         "multiple lines instead of letting it overflow."),
  function() {
    tbl <- tfl_table(
      medclass_df,
      cols = list(tfl_colspec("Concomitant Medication Class",
                              width = grid::unit(0.8, "inches"),
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

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

cat("Demos written to:\n  ", normalizePath(out_dir, mustWork = FALSE), "\n",
    sep = "")
cat("Open the README at:\n  ",
    normalizePath(readme, mustWork = FALSE), "\n", sep = "")
cat("\nOn Windows:  start \"\" \"", normalizePath(out_dir, mustWork = FALSE),
    "\"\n", sep = "")
