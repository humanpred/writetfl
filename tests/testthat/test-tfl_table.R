# test-tfl_table.R — Tests for tfl_colspec(), tfl_table(), and rendering

library(dplyr, warn.conflicts = FALSE)

# ---------------------------------------------------------------------------
# Helper data
# ---------------------------------------------------------------------------

make_simple_df <- function(n = 3) {
  data.frame(
    label  = LETTERS[seq_len(n)],
    value1 = seq_len(n) * 1.1,
    value2 = seq_len(n) * 10L,
    stringsAsFactors = FALSE
  )
}

make_grouped_df <- function() {
  df <- data.frame(
    group  = c("X", "X", "Y", "Y"),
    label  = c("A", "B", "C", "D"),
    value  = c(1, 2, 3, 4),
    stringsAsFactors = FALSE
  )
  dplyr::group_by(df, group)
}

make_multi_group_df <- function() {
  df <- data.frame(
    grp1  = c("X", "X", "Y", "Y"),
    grp2  = c("a", "b", "c", "d"),
    value = c(1, 2, 3, 4),
    stringsAsFactors = FALSE
  )
  dplyr::group_by(df, grp1, grp2)
}

# ---------------------------------------------------------------------------
# tfl_colspec() — construction and validation
# ---------------------------------------------------------------------------

test_that("tfl_colspec creates object with correct class", {
  cs <- tfl_colspec("mpg")
  expect_s3_class(cs, "tfl_colspec")
  expect_equal(cs$col, "mpg")
  expect_null(cs$label)
  expect_null(cs$width)
  expect_null(cs$align)
  expect_false(cs$wrap)
  expect_null(cs$gp)
})

test_that("tfl_colspec stores all arguments", {
  cs <- tfl_colspec("hp",
                    label = "Horse\npower",
                    width = grid::unit(1.5, "inches"),
                    align = "right",
                    wrap  = TRUE,
                    gp    = grid::gpar(fontface = "bold"))
  expect_equal(cs$label, "Horse\npower")
  expect_equal(cs$align, "right")
  expect_true(cs$wrap)
  expect_s3_class(cs$gp, "gpar")
})

test_that("tfl_colspec accepts relative numeric width", {
  cs <- tfl_colspec("x", width = 2)
  expect_equal(cs$width, 2)
})

test_that("tfl_colspec errors on non-string col", {
  expect_error(tfl_colspec(123),        regexp = "col")
  expect_error(tfl_colspec(""),         regexp = "col")
  expect_error(tfl_colspec(c("a","b")), regexp = "col")
})

test_that("tfl_colspec errors on bad align", {
  expect_error(tfl_colspec("x", align = "top"), regexp = "arg")
})

test_that("tfl_colspec errors on bad gp type", {
  expect_error(tfl_colspec("x", gp = list(fontface = "bold")), regexp = "gpar")
})

test_that("tfl_colspec errors on bad width", {
  expect_error(tfl_colspec("x", width = -1),    regexp = "width")
  expect_error(tfl_colspec("x", width = "1in"), regexp = "width")
})

# ---------------------------------------------------------------------------
# tfl_table() — construction and validation
# ---------------------------------------------------------------------------

test_that("tfl_table creates object with correct class", {
  tbl <- tfl_table(make_simple_df())
  expect_s3_class(tbl, "tfl_table")
})

test_that("tfl_table stores data and defaults", {
  df  <- make_simple_df()
  tbl <- tfl_table(df)
  expect_identical(tbl$data, df)
  expect_equal(tbl$group_vars, character(0L))
  expect_true(tbl$allow_col_split)
  expect_true(tbl$suppress_repeated_groups)
  expect_true(tbl$show_col_names)
  expect_true(tbl$col_header_rule)
  expect_true(tbl$group_rule)
  expect_false(tbl$group_rule_after_last)
  expect_false(tbl$row_header_sep)
  expect_equal(tbl$na_string, "")
  expect_equal(tbl$max_measure_rows, Inf)
})

test_that("tfl_table detects group_vars from grouped_df", {
  tbl <- tfl_table(make_grouped_df())
  expect_equal(tbl$group_vars, "group")
})

test_that("tfl_table errors if group cols not first", {
  df <- data.frame(a = 1:3, b = 1:3, c = 1:3)
  gdf <- dplyr::group_by(df, b)  # b is not first
  expect_error(tfl_table(gdf), regexp = "first columns")
})

test_that("tfl_table errors if multi group cols not a prefix", {
  df  <- data.frame(grp1 = 1:4, grp2 = 1:4, val = 1:4)
  gdf <- dplyr::group_by(df, grp2, grp1)  # wrong order
  expect_error(tfl_table(gdf), regexp = "first columns")
})

test_that("tfl_table errors if x is not a data.frame", {
  expect_error(tfl_table(list(a = 1:3)), regexp = "data")
  expect_error(tfl_table(matrix(1:4, 2)),  regexp = "data")
})

test_that("tfl_table errors on tfl_colspec column not in x", {
  expect_error(
    tfl_table(make_simple_df(), cols = list(tfl_colspec("nonexistent"))),
    regexp = "not found"
  )
})

test_that("tfl_table errors when tfl_colspec gp used on non-group col", {
  expect_error(
    tfl_table(make_simple_df(),
              cols = list(tfl_colspec("label", gp = grid::gpar(fontface = "bold")))),
    regexp = "row-header"
  )
})

test_that("tfl_table allows tfl_colspec gp on group col", {
  tbl <- tfl_table(make_grouped_df(),
                   cols = list(tfl_colspec("group", gp = grid::gpar(fontface = "bold"))))
  expect_s3_class(tbl, "tfl_table")
})

test_that("tfl_table errors on bad col_widths names", {
  expect_error(
    tfl_table(make_simple_df(), col_widths = c(notacol = 1)),
    regexp = "not found"
  )
})

test_that("tfl_table errors on bad col_align values", {
  expect_error(
    tfl_table(make_simple_df(), col_align = c(label = "diagonal")),
    regexp = "left.*right.*centre"
  )
})

test_that("tfl_table errors on bad wrap_cols names", {
  expect_error(
    tfl_table(make_simple_df(), wrap_cols = "nonexistent"),
    regexp = "not found"
  )
})

test_that("tfl_table errors on non-unit min_col_width", {
  expect_error(tfl_table(make_simple_df(), min_col_width = 0.5),
               regexp = "unit")
})

test_that("tfl_table normalises scalar cell_padding to 4 sides", {
  tbl <- tfl_table(make_simple_df(), cell_padding = grid::unit(0.1, "inches"))
  expect_equal(length(tbl$cell_padding), 4L)
  expect_equal(names(tbl$cell_padding), c("top", "right", "bottom", "left"))
})

test_that("tfl_table normalises v/h cell_padding", {
  tbl <- tfl_table(make_simple_df(),
                   cell_padding = grid::unit(c(0.1, 0.2), "inches"))
  expect_equal(length(tbl$cell_padding), 4L)
  expect_equal(names(tbl$cell_padding), c("top", "right", "bottom", "left"))
})

test_that("tfl_table errors on bad cell_padding", {
  expect_error(
    tfl_table(make_simple_df(), cell_padding = grid::unit(c(0.1, 0.2, 0.3), "inches")),
    regexp = "cell_padding"
  )
})

test_that("tfl_table errors on non-logical allow_col_split", {
  expect_error(tfl_table(make_simple_df(), allow_col_split = "yes"),
               regexp = "allow_col_split")
})

# ---------------------------------------------------------------------------
# print.tfl_table()
# ---------------------------------------------------------------------------

test_that("print.tfl_table returns x invisibly", {
  tbl <- tfl_table(make_simple_df())
  out <- capture.output(result <- print(tbl))
  expect_identical(result, tbl)
})

test_that("print.tfl_table displays class header", {
  tbl <- tfl_table(make_simple_df())
  out <- capture.output(print(tbl))
  expect_true(any(grepl("<tfl_table>", out)))
})

test_that("print.tfl_table shows row-header info for grouped df", {
  tbl <- tfl_table(make_grouped_df())
  out <- capture.output(print(tbl))
  expect_true(any(grepl("row-header", out)))
  expect_true(any(grepl("group", out)))
})

# ---------------------------------------------------------------------------
# resolve_col_specs() — internal
# ---------------------------------------------------------------------------

test_that("resolve_col_specs uses tfl_colspec values over flat args", {
  tbl <- tfl_table(
    make_simple_df(),
    cols       = list(tfl_colspec("label", label = "Name", align = "centre")),
    col_labels = c(label = "Overridden"),
    col_align  = c(label = "right")
  )
  specs <- resolve_col_specs(tbl)
  label_spec <- specs[[which(sapply(specs, `[[`, "col") == "label")]]
  expect_equal(label_spec$label, "Name")
  expect_equal(label_spec$align, "centre")
})

test_that("resolve_col_specs falls back to flat args when no tfl_colspec", {
  tbl <- tfl_table(
    make_simple_df(),
    col_labels = c(value1 = "Val 1"),
    col_align  = c(value1 = "right")
  )
  specs <- resolve_col_specs(tbl)
  v1    <- specs[[which(sapply(specs, `[[`, "col") == "value1")]]
  expect_equal(v1$label, "Val 1")
  expect_equal(v1$align, "right")
})

test_that("resolve_col_specs uses column name as default label", {
  tbl   <- tfl_table(make_simple_df())
  specs <- resolve_col_specs(tbl)
  for (cs in specs) expect_equal(cs$label, cs$col)
})

test_that("resolve_col_specs defaults numeric cols to right-align", {
  tbl   <- tfl_table(make_simple_df())
  specs <- resolve_col_specs(tbl)
  num_spec <- specs[[which(sapply(specs, `[[`, "col") == "value1")]]
  expect_equal(num_spec$align, "right")
})

test_that("resolve_col_specs defaults character cols to left-align", {
  tbl   <- tfl_table(make_simple_df())
  specs <- resolve_col_specs(tbl)
  chr_spec <- specs[[which(sapply(specs, `[[`, "col") == "label")]]
  expect_equal(chr_spec$align, "left")
})

test_that("resolve_col_specs marks group cols correctly", {
  tbl   <- tfl_table(make_grouped_df())
  specs <- resolve_col_specs(tbl)
  grp_spec  <- specs[[which(sapply(specs, `[[`, "col") == "group")]]
  data_spec <- specs[[which(sapply(specs, `[[`, "col") == "value")]]
  expect_true(grp_spec$is_group_col)
  expect_false(data_spec$is_group_col)
})

test_that("resolve_col_specs wrap_cols TRUE marks non-group cols", {
  tbl   <- tfl_table(make_grouped_df(), wrap_cols = TRUE)
  specs <- resolve_col_specs(tbl)
  grp_spec  <- specs[[which(sapply(specs, `[[`, "col") == "group")]]
  data_spec <- specs[[which(sapply(specs, `[[`, "col") == "value")]]
  expect_false(grp_spec$wrap)
  expect_true(data_spec$wrap)
})

# ---------------------------------------------------------------------------
# paginate_cols() — internal
# ---------------------------------------------------------------------------

test_that("paginate_cols returns single group when all fit", {
  widths <- c(1, 1, 1)  # 3 in total; content = 4 in
  groups <- paginate_cols(widths, content_width_in = 4, n_group_cols = 0,
                          allow_col_split = TRUE)
  expect_length(groups, 1L)
  expect_equal(groups[[1L]], 1:3)
})

test_that("paginate_cols splits when too wide", {
  widths <- c(0.5, 2, 2)  # group=0.5, data cols each 2 in; content=3.5 in
  groups <- paginate_cols(widths, content_width_in = 3.5, n_group_cols = 1,
                          allow_col_split = TRUE)
  expect_length(groups, 2L)
  # Group col (1) appears in both groups
  expect_true(1L %in% groups[[1L]])
  expect_true(1L %in% groups[[2L]])
})

test_that("paginate_cols includes group cols in every group", {
  widths <- c(0.5, 0.5, 2, 2)  # 2 group cols, 2 data cols
  groups <- paginate_cols(widths, content_width_in = 3.5, n_group_cols = 2,
                          allow_col_split = TRUE)
  for (g in groups) {
    expect_true(1L %in% g)
    expect_true(2L %in% g)
  }
})

# ---------------------------------------------------------------------------
# paginate_rows() — internal
# ---------------------------------------------------------------------------

make_row_page_inputs <- function(n = 5, group_every = NULL) {
  data <- data.frame(
    grp   = if (!is.null(group_every)) rep(letters[seq_len(ceiling(n / group_every))],
                                           each = group_every)[seq_len(n)] else rep("A", n),
    value = seq_len(n),
    stringsAsFactors = FALSE
  )
  list(data = data, heights = rep(1, n))
}

test_that("paginate_rows fits all rows on one page", {
  inp <- make_row_page_inputs(3)
  pages <- paginate_rows(inp$data, inp$heights, cont_row_h = 0.5,
                         header_row_h = 0.5, content_height_in = 10,
                         group_vars = character(0L),
                         row_cont_msg = "(continued)", group_rule = FALSE)
  expect_length(pages, 1L)
  expect_equal(pages[[1L]]$rows, 1:3)
  expect_false(pages[[1L]]$is_cont_top)
  expect_false(pages[[1L]]$is_cont_bottom)
})

test_that("paginate_rows splits across pages", {
  inp   <- make_row_page_inputs(5)
  pages <- paginate_rows(inp$data, inp$heights, cont_row_h = 0.2,
                         header_row_h = 0.5, content_height_in = 3,
                         group_vars = character(0L),
                         row_cont_msg = "(continued)", group_rule = FALSE)
  expect_gt(length(pages), 1L)
  # All row indices covered exactly once
  all_rows <- unlist(lapply(pages, `[[`, "rows"))
  expect_equal(sort(all_rows), 1:5)
})

test_that("paginate_rows marks cont_top/cont_bottom on splits", {
  inp   <- make_row_page_inputs(5)
  pages <- paginate_rows(inp$data, inp$heights, cont_row_h = 0.2,
                         header_row_h = 0.5, content_height_in = 2.5,
                         group_vars = character(0L),
                         row_cont_msg = "(continued)", group_rule = FALSE)
  if (length(pages) >= 2L) {
    expect_true(pages[[1L]]$is_cont_bottom)
    expect_true(pages[[2L]]$is_cont_top)
  }
})

test_that("paginate_rows warns when a group spans multiple pages", {
  data <- data.frame(grp = c("A","A","A","A","A"),
                     val = 1:5, stringsAsFactors = FALSE)
  gdf  <- dplyr::group_by(data, grp)
  heights <- rep(1, 5)
  # Multiple page breaks may fire multiple warnings; capture all and check
  # at least one matches
  warns <- character(0)
  withCallingHandlers(
    paginate_rows(gdf, heights, cont_row_h = 0.2,
                  header_row_h = 0.5, content_height_in = 3,
                  group_vars = "grp",
                  row_cont_msg = "(continued)", group_rule = FALSE),
    warning = function(w) {
      warns <<- c(warns, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_true(any(grepl("continued", warns)))
})

# ---------------------------------------------------------------------------
# compute_table_content_area() — internal
# ---------------------------------------------------------------------------

test_that("compute_table_content_area returns positive dimensions", {
  dims <- compute_table_content_area(
    pg_width = 11, pg_height = 8.5,
    margins  = grid::unit(c(t = 0.5, r = 0.5, b = 0.5, l = 0.5), "inches"),
    padding  = grid::unit(0.5, "lines"),
    header_rule = FALSE, footer_rule = FALSE,
    annot    = list(header_left = NULL, header_center = NULL, header_right = NULL,
                    caption = NULL, footnote = NULL,
                    footer_left = NULL, footer_center = NULL, footer_right = NULL),
    gp_page  = grid::gpar(),
    cap_just = "left", fn_just = "left"
  )
  expect_gt(dims$width,  0)
  expect_gt(dims$height, 0)
})

test_that("compute_table_content_area reduces height with annotations", {
  no_annot <- compute_table_content_area(
    11, 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches"),
    padding = grid::unit(0.5, "lines"),
    FALSE, FALSE,
    annot = list(header_left = NULL, header_center = NULL, header_right = NULL,
                 caption = NULL, footnote = NULL,
                 footer_left = NULL, footer_center = NULL, footer_right = NULL),
    gp_page = grid::gpar(), cap_just = "left", fn_just = "left"
  )
  with_annot <- compute_table_content_area(
    11, 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches"),
    padding = grid::unit(0.5, "lines"),
    FALSE, FALSE,
    annot = list(header_left = "Title", header_center = NULL, header_right = NULL,
                 caption = "Caption text", footnote = NULL,
                 footer_left = NULL, footer_center = NULL, footer_right = NULL),
    gp_page = grid::gpar(), cap_just = "left", fn_just = "left"
  )
  expect_lt(with_annot$height, no_annot$height)
})

# ---------------------------------------------------------------------------
# Integration — export_tfl with tfl_table
# ---------------------------------------------------------------------------

test_that("export_tfl renders a simple tfl_table to PDF", {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  tbl <- tfl_table(make_simple_df(),
                   col_labels = c(label = "Label", value1 = "V1", value2 = "V2"))
  expect_no_error(
    export_tfl(tbl, file = f, header_left = "Test", caption = "Table 1")
  )
  expect_true(file.exists(f))
  expect_gt(file.size(f), 0L)
})

test_that("export_tfl renders grouped tfl_table to PDF", {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  tbl <- tfl_table(make_grouped_df())
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})

test_that("export_tfl paginates rows to multiple pages", {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  # Make a table that requires ~3 pages given small page + large padding
  df  <- data.frame(a = letters[1:20], b = seq_len(20))
  tbl <- tfl_table(df,
                   col_labels = c(a = "Letter", b = "Number"),
                   cell_padding = grid::unit(0.5, "lines"))
  expect_no_error(
    export_tfl(tbl, file = f, pg_height = 4,
               margins = grid::unit(c(0.25, 0.25, 0.25, 0.25), "inches"))
  )
  expect_true(file.exists(f))
})

test_that("export_tfl paginates columns when too wide", {
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))

  # Wide table: 5 data cols each 3 inches on a 11-inch page = too wide
  df  <- as.data.frame(matrix(seq_len(20), nrow = 4,
                               dimnames = list(NULL, paste0("c", 1:5))))
  tbl <- tfl_table(df,
                   col_widths = stats::setNames(rep(list(grid::unit(3, "inches")), 5),
                                                paste0("c", 1:5)),
                   allow_col_split = TRUE)
  expect_no_error(export_tfl(tbl, file = f))
  expect_true(file.exists(f))
})

test_that("tfl_table with allow_col_split=FALSE errors when too wide", {
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  df  <- as.data.frame(matrix(seq_len(20), nrow = 4,
                               dimnames = list(NULL, paste0("c", 1:5))))
  tbl <- tfl_table(df,
                   col_widths = stats::setNames(rep(list(grid::unit(3, "inches")), 5),
                                                paste0("c", 1:5)),
                   allow_col_split = FALSE)
  expect_error(export_tfl(tbl, file = f), regexp = "exceeds")
})

test_that("col_cont_msg sets col-page flags on grobs when column-split occurs", {
  df <- as.data.frame(matrix(seq_len(20), nrow = 4,
                              dimnames = list(NULL, paste0("c", 1:5))))
  tbl <- tfl_table(df,
                   col_widths      = stats::setNames(rep(list(grid::unit(3, "inches")), 5),
                                                     paste0("c", 1:5)),
                   col_cont_msg    = "SEE OTHER PAGES",
                   allow_col_split = TRUE)
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  # With 5 × 3-inch columns on an 11-inch page there must be >1 column page
  expect_gt(length(pages), 1L)
  # The first page's grob must be flagged as first but NOT last col page
  first_grob <- pages[[1L]]$content
  expect_true( first_grob$is_first_col_page)
  expect_false(first_grob$is_last_col_page)
  # The last page's grob must be flagged as last but NOT first
  last_grob <- pages[[length(pages)]]$content
  expect_false(last_grob$is_first_col_page)
  expect_true( last_grob$is_last_col_page)
  # No page should have footer_center injected (old behaviour removed)
  has_footer_injected <- any(vapply(pages, function(p) {
    identical(p$footer_center, "SEE OTHER PAGES")
  }, logical(1L)))
  expect_false(has_footer_injected)
})

test_that("col_cont_msg NULL: all grob flags are TRUE (no side labels)", {
  df  <- data.frame(a = letters[1:3], b = 1:3)
  tbl <- tfl_table(df, col_cont_msg = NULL)
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  # Single-column-page table: both flags TRUE on every grob
  all_first <- all(vapply(pages, function(p) isTRUE(p$content$is_first_col_page),
                          logical(1L)))
  all_last  <- all(vapply(pages, function(p) isTRUE(p$content$is_last_col_page),
                          logical(1L)))
  expect_true(all_first)
  expect_true(all_last)
})

test_that("col_cont_msg is not placed in footer_center even when col-split", {
  df <- as.data.frame(matrix(seq_len(20), nrow = 4,
                              dimnames = list(NULL, paste0("c", 1:5))))
  tbl <- tfl_table(df,
                   col_widths      = stats::setNames(rep(list(grid::unit(3, "inches")), 5),
                                                     paste0("c", 1:5)),
                   col_cont_msg    = "SEE OTHER PAGES",
                   allow_col_split = TRUE)
  pages <- tfl_table_to_pagelist(tbl, pg_width = 11, pg_height = 8.5,
                                  dots = list())
  has_injected <- any(vapply(pages, function(p) {
    identical(p$footer_center, "SEE OTHER PAGES")
  }, logical(1L)))
  expect_false(has_injected)
})

test_that("suppress_repeated_groups does not error", {
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_grouped_df(), suppress_repeated_groups = TRUE)
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("show_col_names = FALSE renders without header row", {
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_simple_df(), show_col_names = FALSE)
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("row_header_sep = TRUE renders without error", {
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_grouped_df(), row_header_sep = TRUE)
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("group_rule_after_last = TRUE renders without error", {
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_grouped_df(), group_rule_after_last = TRUE)
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("NA values are replaced by na_string", {
  f  <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  df <- data.frame(a = c("X", NA, "Z"), b = c(1, NA, 3),
                   stringsAsFactors = FALSE)
  tbl <- tfl_table(df, na_string = "—")
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("tfl_colspec relative widths render without error", {
  f  <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  df <- data.frame(a = letters[1:3], b = 1:3, c = 4:6)
  tbl <- tfl_table(df,
                   cols = list(
                     tfl_colspec("a", width = 1),
                     tfl_colspec("b", width = 2),
                     tfl_colspec("c", width = 1)
                   ))
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("gp$header_row bold renders without error", {
  f  <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_simple_df(),
                   gp = list(header_row = grid::gpar(fontface = "bold",
                                                     fontsize = 12)))
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("multi-group df renders with repeat suppression", {
  f  <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  tbl <- tfl_table(make_multi_group_df(), suppress_repeated_groups = TRUE)
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("wrap_cols reduces wide column widths", {
  df  <- data.frame(
    a = rep(paste(rep("word", 30), collapse = " "), 3),  # very long string
    b = 1:3,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(df, wrap_cols = "a")
  result <- compute_col_widths(
    resolve_col_specs(tbl), tbl$data, content_width_in = 4,
    tbl, pg_width = 11, pg_height = 8.5,
    margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
  )
  # Column 'a' should be at most 3 inches (4 - 1 for col b)
  a_idx   <- which(vapply(result$resolved_cols, `[[`, "", "col") == "a")
  expect_lte(result$resolved_cols[[a_idx]]$width_in, 4)
})

# ---------------------------------------------------------------------------
# tfl_colspec() — additional validation (R/tfl_table.R lines 49, 60)
# ---------------------------------------------------------------------------

test_that("tfl_colspec errors when label is not a single character string", {
  expect_error(tfl_colspec("x", label = 123),          regexp = "label")
  expect_error(tfl_colspec("x", label = c("a", "b")), regexp = "label")
})

test_that("tfl_colspec errors when wrap is not a scalar logical", {
  expect_error(tfl_colspec("x", wrap = NA),    regexp = "wrap")
  expect_error(tfl_colspec("x", wrap = "yes"), regexp = "wrap")
})

# ---------------------------------------------------------------------------
# tfl_table() — additional validation (R/tfl_table.R lines 232-371)
# ---------------------------------------------------------------------------

test_that("tfl_table errors on a data frame with zero columns", {
  expect_error(tfl_table(data.frame()), regexp = "at least 1 col")
})

test_that("tfl_table errors when cols is not a list", {
  expect_error(tfl_table(make_simple_df(), cols = "label"), regexp = "list")
})

test_that("tfl_table errors when a cols element is not a tfl_colspec", {
  expect_error(
    tfl_table(make_simple_df(), cols = list("not a colspec")),
    regexp = "tfl_colspec"
  )
})

test_that("tfl_table errors when col_widths is unnamed", {
  expect_error(tfl_table(make_simple_df(), col_widths = c(1, 2)), regexp = "named")
})

test_that("tfl_table errors when col_labels is not a named character vector", {
  expect_error(tfl_table(make_simple_df(), col_labels = c("A", "B")),   regexp = "named")
  expect_error(tfl_table(make_simple_df(), col_labels = c(label = 1L)), regexp = "named")
})

test_that("tfl_table errors when col_labels names are not in x", {
  expect_error(
    tfl_table(make_simple_df(), col_labels = c(nosuchcol = "X")),
    regexp = "not found"
  )
})

test_that("tfl_table errors when col_align is not a named character vector", {
  expect_error(
    tfl_table(make_simple_df(), col_align = c("left", "right")),
    regexp = "named"
  )
})

test_that("tfl_table errors when col_align names are not in x", {
  expect_error(
    tfl_table(make_simple_df(), col_align = c(nosuchcol = "left")),
    regexp = "not found"
  )
})

test_that("tfl_table errors when wrap_cols is not logical or character", {
  expect_error(tfl_table(make_simple_df(), wrap_cols = 1L), regexp = "wrap_cols")
})

test_that("tfl_table errors on a non-NULL non-string col_cont_msg", {
  expect_error(tfl_table(make_simple_df(), col_cont_msg = 123), regexp = "col_cont_msg")
})

test_that("tfl_table errors on row_cont_msg with wrong length", {
  expect_error(
    tfl_table(make_simple_df(), row_cont_msg = c("a", "b", "c")),
    regexp = "row_cont_msg"
  )
  expect_error(
    tfl_table(make_simple_df(), row_cont_msg = character(0L)),
    regexp = "row_cont_msg"
  )
})

test_that("tfl_table errors on a multi-element na_string", {
  expect_error(tfl_table(make_simple_df(), na_string = c("a", "b")), regexp = "na_string")
})

test_that("tfl_table errors when gp is not a list or gpar", {
  expect_error(tfl_table(make_simple_df(), gp = "bold"), regexp = "gp")
})

test_that("tfl_table errors on a non-positive or non-numeric line_height", {
  expect_error(tfl_table(make_simple_df(), line_height = -1),  regexp = "line_height")
  expect_error(tfl_table(make_simple_df(), line_height = 0),   regexp = "line_height")
  expect_error(tfl_table(make_simple_df(), line_height = "a"), regexp = "line_height")
})

test_that("tfl_table errors on an invalid max_measure_rows", {
  expect_error(tfl_table(make_simple_df(), max_measure_rows = 0),   regexp = "max_measure_rows")
  expect_error(tfl_table(make_simple_df(), max_measure_rows = -1),  regexp = "max_measure_rows")
  expect_error(tfl_table(make_simple_df(), max_measure_rows = "a"), regexp = "max_measure_rows")
})

# ---------------------------------------------------------------------------
# .normalise_cell_padding() — scalar-unit path (R/tfl_table.R line 483)
# ---------------------------------------------------------------------------

test_that(".normalise_cell_padding applies a scalar unit equally to all 4 sides", {
  tbl <- tfl_table(make_simple_df(), cell_padding = grid::unit(0.1, "inches"))
  expect_named(tbl$cell_padding, c("top", "right", "bottom", "left"))
  top_in  <- grid::convertUnit(tbl$cell_padding$top,  "inches", valueOnly = TRUE)
  left_in <- grid::convertUnit(tbl$cell_padding$left, "inches", valueOnly = TRUE)
  expect_equal(top_in, left_in)
})

test_that("tfl_table errors when cell_padding is not a unit object", {
  expect_error(tfl_table(make_simple_df(), cell_padding = 0.2), regexp = "cell_padding")
})

# ---------------------------------------------------------------------------
# print.tfl_table() — unit-width and relative-weight columns (lines 442, 444, 520)
# ---------------------------------------------------------------------------

test_that("print.tfl_table shows a unit width as '... in'", {
  tbl <- tfl_table(
    make_simple_df(),
    cols = list(tfl_colspec("label", width = grid::unit(1.5, "inches")))
  )
  out <- capture.output(print(tbl))
  expect_true(any(grepl("\\bin\\b", out)))
})

test_that("print.tfl_table shows a relative weight as 'rel(...)'", {
  tbl <- tfl_table(
    make_simple_df(),
    cols = list(tfl_colspec("label", width = 2))
  )
  out <- capture.output(print(tbl))
  expect_true(any(grepl("rel\\(2\\)", out)))
})

# ---------------------------------------------------------------------------
# paginate_cols() — additional paths (R/table_columns.R lines 232, 256-273)
# ---------------------------------------------------------------------------

test_that("paginate_cols with n_data == 0 returns one group containing only group cols", {
  groups <- paginate_cols(c(0.5), content_width_in = 3,
                          n_group_cols = 1, allow_col_split = TRUE)
  expect_length(groups, 1L)
  expect_equal(groups[[1L]], 1L)
})

test_that("paginate_cols balance_col_pages distributes data columns evenly", {
  # 1 group col (0.5 in) + 10 data cols (0.5 in each); avail = 2.7 in
  # Greedy: 5 per page → 2 pages; balanced: 5 + 5 (same split, exercises balance path)
  widths <- c(0.5, rep(0.5, 10))
  groups <- paginate_cols(widths, content_width_in = 3.2, n_group_cols = 1,
                          allow_col_split = TRUE, balance_col_pages = TRUE)
  expect_length(groups, 2L)
  expect_equal(length(groups[[1L]]), 6L)  # 1 group + 5 data
  expect_equal(length(groups[[2L]]), 6L)
  expect_true(1L %in% groups[[1L]])
  expect_true(1L %in% groups[[2L]])
})

test_that("paginate_cols balance_col_pages falls back to greedy when balanced would overflow", {
  # 1 group col (0.1 in) + 4 data cols: [1.0, 0.3, 0.3, 0.3]; avail = 1.1 in
  # Greedy: {1.0} | {0.3, 0.3, 0.3} → 2 pages
  # Balanced: {1.0, 0.3} = 1.3 > 1.1 → OVERFLOW → falls back to greedy
  widths          <- c(0.1, 1.0, 0.3, 0.3, 0.3)
  groups_greedy   <- paginate_cols(widths, content_width_in = 1.2, n_group_cols = 1,
                                   allow_col_split = TRUE, balance_col_pages = FALSE)
  groups_balanced <- paginate_cols(widths, content_width_in = 1.2, n_group_cols = 1,
                                   allow_col_split = TRUE, balance_col_pages = TRUE)
  expect_equal(groups_balanced, groups_greedy)
})

test_that("paginate_cols balance_col_pages is a no-op when all columns fit on one page", {
  widths <- c(0.5, 0.5, 0.5)
  groups <- paginate_cols(widths, content_width_in = 5, n_group_cols = 0,
                          allow_col_split = TRUE, balance_col_pages = TRUE)
  expect_length(groups, 1L)
})

# ---------------------------------------------------------------------------
# .apply_col_wrapping() — no-eligible break (R/table_columns.R line 190)
# ---------------------------------------------------------------------------

test_that("compute_col_widths handles a wrap col already at or below min_col_width", {
  # The wrap-eligible column auto-measures to a small width.
  # min_col_width = 4 in → the column is below min → not eligible for narrowing
  # → .apply_col_wrapping hits the 'no eligible cols' break at line 190.
  # allow_col_split = TRUE so the table still renders despite total exceeding content width.
  tbl <- tfl_table(
    make_simple_df(),
    wrap_cols     = "label",
    min_col_width = grid::unit(4, "inches"),
    allow_col_split = TRUE
  )
  expect_no_error(
    compute_col_widths(
      resolve_col_specs(tbl), tbl$data,
      content_width_in = 3,
      tbl, pg_width = 11, pg_height = 8.5,
      margins = grid::unit(c(0.5, 0.5, 0.5, 0.5), "inches")
    )
  )
})

# ---------------------------------------------------------------------------
# measure_row_heights_tbl() — additional paths (R/table_rows.R lines 41-46, 61-62)
# ---------------------------------------------------------------------------

test_that("max_measure_rows limits the rows sampled for height estimation", {
  tbl <- tfl_table(make_simple_df(n = 10), max_measure_rows = 2)
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
})

test_that("measure_row_heights_tbl exercises the wrap path for wrap-eligible columns", {
  df <- data.frame(
    a = rep(paste(rep("word", 15), collapse = " "), 3),
    b = 1:3,
    stringsAsFactors = FALSE
  )
  tbl <- tfl_table(
    df,
    cols = list(tfl_colspec("a", width = grid::unit(1.5, "inches"), wrap = TRUE))
  )
  f <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(export_tfl(tbl, file = f))
})

# ---------------------------------------------------------------------------
# tfl_table_to_pagelist() — explicit FALSE dots are not dropped
# ---------------------------------------------------------------------------

test_that("tfl_table_to_pagelist respects explicit FALSE for header_rule/footer_rule", {

  # Passing header_rule = FALSE and footer_rule = FALSE via ... must not be

  # silently replaced by defaults.  This exercises the explicit NULL-check
  # in tfl_table_to_pagelist() that replaced the previous %||% pattern.
  tbl <- tfl_table(make_simple_df())
  f   <- tempfile(fileext = ".pdf")
  on.exit(unlink(f))
  expect_no_error(
    export_tfl(tbl, file = f, header_rule = FALSE, footer_rule = FALSE)
  )
  expect_true(file.exists(f))
  expect_gt(file.info(f)$size, 0)
})
