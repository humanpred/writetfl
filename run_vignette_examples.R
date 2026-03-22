setwd("C:/git/ggformatters")
devtools::load_all(quiet = TRUE)
library(dplyr)

tmp <- tempdir()
old <- setwd(tmp)
on.exit(setwd(old), add = TRUE)

run_chunk <- function(name, expr) {
  cat(sprintf("\n=== %s ===\n", name))
  result <- tryCatch(
    { force(expr); cat("  OK\n") },
    error   = function(e) cat(sprintf("  ERROR: %s\n", conditionMessage(e))),
    warning = function(w) cat(sprintf("  WARNING: %s\n", conditionMessage(w)))
  )
}

# --- basic ---
run_chunk("basic", {
  tbl <- tfl_table(head(mtcars, 20))
  export_tfl(tbl, file = "basic_table.pdf",
    header_left = "Table 1. Motor Trend Car Road Tests (first 20 rows)",
    footer_left = "Source: Motor Trend (1974)", header_rule = TRUE)
})

# --- col-labels ---
run_chunk("col-labels", {
  tbl <- tfl_table(head(mtcars, 20)[, c("mpg", "cyl", "hp", "wt")],
    col_labels = c(mpg = "Miles/Gallon", cyl = "Cylinders",
                   hp = "Horsepower", wt = "Weight\n(1000 lb)"))
  export_tfl(tbl, file = "labeled_columns.pdf",
    header_left = "Table 1. Selected Performance Metrics")
})

# --- col-widths ---
run_chunk("col-widths", {
  tbl <- tfl_table(head(mtcars, 20)[, c("mpg", "cyl", "hp", "wt", "gear")],
    col_widths = list(mpg = unit(1.2, "inches"), cyl = 1, hp = 1,
                      wt = unit(1.4, "inches"), gear = NULL))
  export_tfl(tbl, file = "column_widths.pdf")
})

# --- col-align ---
run_chunk("col-align", {
  ae_summary <- data.frame(
    system_organ_class = c("Gastrointestinal", "Nervous system", "Skin"),
    n_subjects = c(12L, 7L, 4L), pct = c(24.0, 14.0, 8.0),
    stringsAsFactors = FALSE)
  tbl <- tfl_table(ae_summary,
    col_labels = c(system_organ_class = "System Organ Class",
                   n_subjects = "n", pct = "(%)"),
    col_align = c(system_organ_class = "left", n_subjects = "right",
                  pct = "right"))
  export_tfl(tbl, file = "ae_summary.pdf",
    header_left = "Table 2. Adverse Events by System Organ Class",
    footnote = "Percentages are based on the safety population (N = 50).")
})

# --- grouping ---
run_chunk("grouping", {
  pk_data <- data.frame(
    visit = rep(c("Week 4", "Week 8", "Week 12"), each = 4),
    treatment = rep(c("Placebo", "Active 10 mg", "Active 20 mg", "Active 40 mg"), 3),
    n = c(48L, 50L, 49L, 51L, 45L, 47L, 48L, 50L, 41L, 43L, 44L, 46L),
    mean_auc = c(120.4, 145.2, 178.9, 201.3, 118.7, 148.6, 185.2, 219.4,
                 115.1, 152.3, 191.7, 228.6),
    sd_auc = c(18.2, 22.4, 27.6, 31.1, 17.9, 23.1, 28.4, 32.7,
               17.1, 24.0, 29.2, 34.3),
    stringsAsFactors = FALSE)
  tbl <- pk_data |> group_by(visit) |>
    tfl_table(
      col_labels = c(visit = "Visit", treatment = "Treatment", n = "n",
                     mean_auc = "Mean AUC\n(ng\u00b7h/mL)", sd_auc = "SD"),
      col_widths = list(visit = unit(1.0, "inches"),
                        treatment = unit(1.5, "inches"), n = NULL,
                        mean_auc = unit(1.4, "inches"),
                        sd_auc = unit(0.8, "inches")))
  export_tfl(tbl, file = "pk_summary.pdf",
    header_left = "Table 3. PK Summary by Visit and Treatment",
    footnote = "AUC = area under the concentration-time curve.")
})

# --- row-pagination ---
run_chunk("row-pagination", {
  tbl <- iris |> dplyr::relocate(Species) |> group_by(Species) |>
    tfl_table(
      col_labels = c(Species = "Species", Sepal.Length = "Sepal\nLength",
                     Sepal.Width = "Sepal\nWidth", Petal.Length = "Petal\nLength",
                     Petal.Width = "Petal\nWidth"),
      row_cont_msg = c("(continued from previous page)", "(continued on next page)"),
      col_cont_msg = "(continued)")
  export_tfl(tbl, file = "iris_table.pdf",
    header_left = "Table 4. Iris Measurements by Species",
    header_rule = TRUE, footer_rule = TRUE)
})

# --- col-pagination ---
run_chunk("col-pagination", {
  lab_wide <- data.frame(
    parameter = c("ALT (U/L)", "AST (U/L)", "ALP (U/L)",
                  "Total Bilirubin (mg/dL)", "Creatinine (mg/dL)", "eGFR (mL/min)"),
    scr  = c(28, 22, 74, 0.6, 0.92, 88), bl   = c(30, 24, 76, 0.7, 0.93, 87),
    wk2  = c(33, 26, 79, 0.7, 0.95, 85), wk4  = c(35, 28, 81, 0.8, 0.97, 83),
    wk6  = c(36, 29, 83, 0.8, 0.99, 81), wk8  = c(38, 30, 84, 0.9, 1.01, 79),
    wk12 = c(36, 28, 82, 0.8, 1.02, 78), wk16 = c(34, 27, 80, 0.8, 1.04, 77),
    wk20 = c(33, 26, 78, 0.7, 1.05, 76), wk24 = c(31, 25, 76, 0.7, 1.07, 75),
    wk28 = c(30, 24, 75, 0.6, 1.08, 74), wk32 = c(29, 23, 74, 0.6, 1.09, 73),
    eot  = c(28, 22, 73, 0.6, 1.10, 72), stringsAsFactors = FALSE)
  tbl <- lab_wide |>
    dplyr::group_by(parameter) |>
    tfl_table(
      col_labels = c(parameter = "Lab Parameter", scr = "Screen-\ning",
        bl = "Base-\nline", wk2 = "Week 2", wk4 = "Week 4", wk6 = "Week 6",
        wk8 = "Week 8", wk12 = "Week 12", wk16 = "Week 16", wk20 = "Week 20",
        wk24 = "Week 24", wk28 = "Week 28", wk32 = "Week 32",
        eot = "End of\nTreatment"))
  export_tfl(tbl, file = "lab_wide.pdf",
    header_left = "Table 5. Mean Lab Safety Values by Timepoint",
    header_rule = TRUE)
})

# --- col-pagination-balanced ---
run_chunk("col-pagination-balanced", {
  lab_wide2 <- data.frame(
    parameter = c("ALT (U/L)", "AST (U/L)", "ALP (U/L)",
                  "Total Bilirubin (mg/dL)", "Creatinine (mg/dL)", "eGFR (mL/min)"),
    scr  = c(28, 22, 74, 0.6, 0.92, 88), bl   = c(30, 24, 76, 0.7, 0.93, 87),
    wk2  = c(33, 26, 79, 0.7, 0.95, 85), wk4  = c(35, 28, 81, 0.8, 0.97, 83),
    wk6  = c(36, 29, 83, 0.8, 0.99, 81), wk8  = c(38, 30, 84, 0.9, 1.01, 79),
    wk12 = c(36, 28, 82, 0.8, 1.02, 78), wk16 = c(34, 27, 80, 0.8, 1.04, 77),
    wk20 = c(33, 26, 78, 0.7, 1.05, 76), wk24 = c(31, 25, 76, 0.7, 1.07, 75),
    wk28 = c(30, 24, 75, 0.6, 1.08, 74), wk32 = c(29, 23, 74, 0.6, 1.09, 73),
    eot  = c(28, 22, 73, 0.6, 1.10, 72), stringsAsFactors = FALSE)
  tbl_balanced <- lab_wide2 |>
    dplyr::group_by(parameter) |>
    tfl_table(
      col_labels = c(
        parameter = "Lab Parameter", scr = "Screen-\ning",
        bl = "Base-\nline", wk2 = "Week 2", wk4 = "Week 4", wk6 = "Week 6",
        wk8 = "Week 8", wk12 = "Week 12", wk16 = "Week 16", wk20 = "Week 20",
        wk24 = "Week 24", wk28 = "Week 28", wk32 = "Week 32",
        eot = "End of\nTreatment"),
      balance_col_pages = TRUE)
  export_tfl(tbl_balanced, file = "lab_wide_balanced.pdf",
    header_left = "Table 5b. Mean Lab Safety Values by Timepoint (balanced columns)",
    header_rule = TRUE)
})

# --- col-split-error ---
run_chunk("col-split-error (expect error)", {
  tbl_no_split <- tfl_table(mtcars, allow_col_split = FALSE)
  tryCatch(export_tfl(tbl_no_split, file = "no_split.pdf"),
           error = function(e) cat(sprintf("  (expected error: %s)\n",
                                           conditionMessage(e))))
})

# --- wrap-cols ---
run_chunk("wrap-cols", {
  ae_verbatim <- data.frame(
    subject_id = c("001-001", "001-002", "001-003", "002-001", "002-002"),
    ae_term = c(
      "Nausea and vomiting, mild, considered possibly related to study treatment",
      "Headache, moderate, considered unlikely related",
      "Fatigue, mild, relationship to study drug uncertain",
      "Abdominal pain, moderate, considered probably related",
      "Dizziness, mild, considered possibly related"),
    onset_day = c(3L, 7L, 2L, 14L, 5L), stringsAsFactors = FALSE)
  tbl <- tfl_table(ae_verbatim,
    col_labels = c(subject_id = "Subject ID",
                   ae_term = "Adverse Event (Verbatim)",
                   onset_day = "Onset\n(Day)"),
    col_widths = list(subject_id = unit(0.8, "inches"),
                      ae_term = unit(3.5, "inches"), onset_day = NULL),
    wrap_cols = "ae_term")
  export_tfl(tbl, file = "ae_verbatim.pdf",
    header_left = "Listing 1. Adverse Event Verbatim Terms", header_rule = TRUE)
})

# --- na-string ---
run_chunk("na-string", {
  labs_data <- data.frame(
    subject_id = c("001", "001", "002", "002", "003"),
    visit = c("Baseline", "Week 4", "Baseline", "Week 4", "Baseline"),
    ALT = c(28, 31, NA, 45, 22), AST = c(19, NA, 24, 38, 17),
    stringsAsFactors = FALSE)
  tbl <- labs_data |> group_by(subject_id) |>
    tfl_table(
      col_labels = c(subject_id = "Subject", visit = "Visit",
                     ALT = "ALT\n(U/L)", AST = "AST\n(U/L)"),
      na_string = "NC")
  export_tfl(tbl, file = "labs.pdf",
    header_left = "Table 6. Laboratory Values", footnote = "NC = not collected.")
})

# --- tfl-colspec ---
run_chunk("tfl-colspec", {
  pk_summary <- data.frame(
    param = rep(c("Cmax", "AUC0-inf", "t1/2"), each = 3),
    treatment = rep(c("Placebo", "Active 10 mg", "Active 20 mg"), 3),
    geo_mean = c(0.00, 145.2, 210.8, 0.00, 4820, 7340, 0.00, 8.4, 9.1),
    cv_pct = c(NA, 28.4, 31.2, NA, 22.7, 25.8, NA, 15.3, 17.9),
    stringsAsFactors = FALSE)
  tbl <- pk_summary |> group_by(param) |>
    tfl_table(
      cols = list(
        tfl_colspec("param",     label = "Parameter",       width = unit(1.2, "inches"), align = "left"),
        tfl_colspec("treatment", label = "Treatment",       width = unit(1.5, "inches"), align = "left"),
        tfl_colspec("geo_mean",  label = "Geometric\nMean", width = unit(1.2, "inches"), align = "right"),
        tfl_colspec("cv_pct",    label = "CV%",             width = unit(0.8, "inches"), align = "right")),
      na_string = "--")
  export_tfl(tbl, file = "pk_colspec.pdf",
    header_left = "Table 7. PK Parameters \u2014 Geometric Mean (CV%)",
    footnote = c("CV% = coefficient of variation.", "-- = not applicable (placebo)."))
})

# --- gp ---
run_chunk("gp", {
  tbl <- tfl_table(head(mtcars, 15)[, c("mpg", "cyl", "hp", "wt")],
    col_labels = c(mpg = "MPG", cyl = "Cylinders", hp = "Horsepower", wt = "Weight"),
    gp = list(
      header = gpar(fontsize = 9, fontface = "bold"),
      body   = gpar(fontsize = 9)))
  export_tfl(tbl, file = "typed_table.pdf", gp = gpar(fontsize = 9))
})

# --- annotations ---
run_chunk("annotations", {
  tbl <- tfl_table(head(iris, 30),
    col_labels = c(Species = "Species", Sepal.Length = "Sepal\nLength",
                   Sepal.Width = "Sepal\nWidth", Petal.Length = "Petal\nLength",
                   Petal.Width = "Petal\nWidth"))
  export_tfl(tbl, file = "iris_annotated.pdf",
    pg_width = 8.5, pg_height = 11,
    margins = unit(c(t = 1, r = 0.75, b = 1, l = 0.75), "inches"),
    header_left = "Protocol XY-001\nDraft \u2014 Not for Distribution",
    header_center = "CONFIDENTIAL",
    header_right = format(Sys.Date(), "%d %b %Y"),
    caption = "Table 8. Iris Sepal and Petal Measurements.",
    footnote = "Data: Fisher (1936). All measurements in centimetres.",
    footer_left = "Department of Statistics",
    footer_right = "Page 1 of 1",
    header_rule = TRUE, footer_rule = TRUE)
})

cat("\n=== Done ===\n")
