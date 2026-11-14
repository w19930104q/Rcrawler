# Offline test helper: the package imports heavy optional deps
# (data.table/httr/webdriver/...) that are not installed in this
# environment, so the grouped engine and its ContentScraper entry point
# are loaded by sourcing the two relevant files instead of loading the
# whole package. A stubbed LinkExtractor serves local fixture files,
# which keeps the Url entry point fully offline and deterministic.

# testthat sources helper files into an environment whose functions are
# visible to test files; source into the current (helper) environment.
helper_env <- environment()

# The scraper calls xml2/selectr via :: so only the packages must be on
# the search path; legacy paths also call a few xml2 functions unqualified.
suppressPackageStartupMessages({
  library(xml2)
  library(selectr)
})

r_root <- normalizePath(file.path(test_path(), "..", "..", "R"),
                        mustWork = TRUE)
sys.source(file.path(r_root, "tools.R"), envir = helper_env)
sys.source(file.path(r_root, "contentscraper_grouped.R"), envir = helper_env)
sys.source(file.path(r_root, "contentscraper.R"), envir = helper_env)

make_link_stub <- function(fixture_dir) {
  # Injected into the execution environment of ContentScraper below.
  function(url, ...) {
    map <- c(
      "http://example.test/a" = file.path(fixture_dir, "comments_a.html"),
      "http://example.test/b" = file.path(fixture_dir, "comments_b.html"),
      "http://example.test/missing" = NA
    )
    if (is.na(map[[url]]) || !file.exists(map[[url]])) {
      return(list(Info = list(Status_code = 404, Source_page = "")))
    }
    list(Info = list(Status_code = 200,
                     Source_page = paste(readLines(map[[url]],
                                                   warn = FALSE),
                                         collapse = "\n")))
  }
}

# Run ContentScraper with the stubbed LinkExtractor visible inside it.
run_scraper <- function(stub, ...) {
  environment(ContentScraper)$LinkExtractor <- stub
  ContentScraper(...)
}
