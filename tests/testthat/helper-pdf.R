# Count "/Type /Page" objects in a PDF via raw-byte matching (avoids a
# pdftools dependency; PDF streams contain embedded nuls so rawToChar is unsafe).
count_pdf_pages <- function(path) {
  raw     <- readBin(path, "raw", n = file.info(path)$size)
  n_page  <- length(grepRaw("/Type /Page",  raw, all = TRUE))
  n_pages <- length(grepRaw("/Type /Pages", raw, all = TRUE))
  n_page - n_pages
}
