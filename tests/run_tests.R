# Offline regression entry point for Rcrawler.
#
# The package's heavy optional dependencies (data.table, httr, webdriver,
# ...) are not required by the ContentScraper engine and may be absent in
# a minimal CI environment, so the scraper is exercised by sourcing its
# R files (see tests/testthat/helper-grouped.R) rather than by
# library(Rcrawler). Run from the package root with:
#
#   Rscript --slave -f tests/run_tests.R
#
suppressPackageStartupMessages(library(testthat))

root <- normalizePath(file.path(getwd()), mustWork = TRUE)
test_dir(file.path(root, "tests", "testthat"),
         reporter = "summary",
         stop_on_failure = TRUE)
