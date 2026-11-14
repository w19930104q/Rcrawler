fixture_dir <- test_path("fixtures")
html_a <- paste(readLines(file.path(fixture_dir, "comments_a.html"),
                          warn = FALSE), collapse = "\n")
html_b <- paste(readLines(file.path(fixture_dir, "comments_b.html"),
                          warn = FALSE), collapse = "\n")
stub <- make_link_stub(fixture_dir)

# ---------------------------------------------------------------------------
# 1. CSS grouped extraction: one row per card, declared column order, NA
#    Without exclusion the nested card living inside the quote is also a
#    .comment, so it is enumerated too; structural exclusion is tested below.
# ---------------------------------------------------------------------------
test_that("CSS grouped mode returns one aligned row per card with NA gaps", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment")

  expect_s3_class(out, "data.frame")
  expect_equal(names(out), c("author", "date", "body"))
  expect_equal(nrow(out), 4)
  expect_equal(out$author, c("Alice", "Nested Quoted Author", "Bob", "Carol"))
  # every column has exactly one cell per row (vectors stay aligned)
  expect_true(all(vapply(out, length, integer(1)) == 4))
  # Bob's card has no date: NA stays in its row instead of shifting columns
  expect_true(is.na(out$date[out$author == "Bob"]))
  # Carol's card has no body
  expect_true(is.na(out$body[out$author == "Carol"]))
  # the nested card's fields never leak into Alice's (outer) row
  expect_equal(out$date[out$author == "Alice"], "2024-01-01")
})

# ---------------------------------------------------------------------------
# 2. XPath grouped extraction, including a relative (./) field selector
# ---------------------------------------------------------------------------
test_that("XPath grouped mode works with absolute and relative field paths", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    XpathPatterns = c("//*[contains(@class,'author')]",
                      "./descendant::span[contains(@class,'date')]",
                      "//p[contains(@class,'body')]"),
    PatternsName = c("author", "date", "body"),
    ContainerXpathPat = "//div[contains(@class,'comment')]")

  expect_equal(names(out), c("author", "date", "body"))
  expect_equal(out$author, c("Alice", "Nested Quoted Author", "Bob", "Carol"))
  # Nested card inside the quote is still enumerated until exclusion is
  # requested; with exclusion (next test) it disappears. Here we only assert
  # alignment semantics: every row has exactly 3 cells and NAs stay in place.
  expect_equal(nrow(out), 4)
  expect_true(all(vapply(out, length, integer(1)) == 4))
})

# ---------------------------------------------------------------------------
# 3. Structural exclusion of nested quotes/ads
# ---------------------------------------------------------------------------
test_that("nested quote/ad structures are removed before card enumeration", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))

  # The nested .comment lived inside .quote, so it is gone: 3 top-level cards
  expect_equal(nrow(out), 3)
  expect_equal(out$author, c("Alice", "Bob", "Carol"))
  expect_equal(out$body[1], "First real comment body")
  # exclusion removed nodes, not text fragments: nothing was string-replaced
  expect_false(any(grepl("BUY THIS|quoted|Nested", unlist(out), fixed = FALSE)))
  # script text never leaks into extracted text
  expect_false(any(grepl("SCRIPT_SHOULD_NOT_APPEAR", unlist(out), fixed = TRUE)))
})

test_that("exclusion is structural under XPath mode as well", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    XpathPatterns = c("//*[contains(@class,'author')]",
                      "//span[contains(@class,'date')]",
                      "//p[contains(@class,'body')]"),
    PatternsName = c("author", "date", "body"),
    ContainerXpathPat = "//div[contains(@class,'comment')]",
    ExcludeXpathPat = c("//blockquote[contains(@class,'quote')]",
                        "//ins[contains(@class,'ads')]"))

  expect_equal(nrow(out), 3)
  expect_equal(out$author, c("Alice", "Bob", "Carol"))
  expect_equal(out$body[1], "First real comment body")
})

# ---------------------------------------------------------------------------
# 4. Sibling cards never share values
# ---------------------------------------------------------------------------
test_that("a field is scoped to its own card and never leaks across siblings", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date"),
    PatternsName = c("author", "date"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))

  expect_equal(out$author, c("Alice", "Bob", "Carol"))
  # Carol has a date; Bob does not: Bob's cell must remain NA rather than
  # take Carol's or Alice's value.
  expect_equal(which(is.na(out$date)), 2)
})

# ---------------------------------------------------------------------------
# 5. Url and HTmlText entries produce identical results
# ---------------------------------------------------------------------------
test_that("Url entry matches HTmlText entry exactly", {
  via_html <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))

  via_url <- run_scraper(stub,
    Url = "http://example.test/a",
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))

  expect_equal(via_url, via_html)
})

# ---------------------------------------------------------------------------
# 6. Multiple URLs preserve input order and append rows page after page
# ---------------------------------------------------------------------------
test_that("multiple URLs keep input order with appended rows", {
  out <- run_scraper(stub,
    Url = c("http://example.test/a", "http://example.test/b"),
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))

  expect_equal(nrow(out), 5)
  expect_equal(out$author, c("Alice", "Bob", "Carol", "Dana", "Evan"))
  expect_equal(out$body[4], "Page B first comment")
  expect_equal(out$body[5], "Page B second comment")

  # reversed input -> reversed page blocks
  out_rev <- run_scraper(stub,
    Url = c("http://example.test/b", "http://example.test/a"),
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))
  expect_equal(out_rev$author, c("Dana", "Evan", "Alice", "Bob", "Carol"))
})

# ---------------------------------------------------------------------------
# 7. Repeated runs are independent (node removal has no carry-over)
# ---------------------------------------------------------------------------
test_that("repeated runs return identical results", {
  args <- list(
    HTmlText = html_a,
    CssPatterns = c(".author", ".date", ".body"),
    PatternsName = c("author", "date", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))
  r1 <- do.call(run_scraper, c(list(stub), args))
  r2 <- do.call(run_scraper, c(list(stub), args))
  r3 <- do.call(run_scraper, c(list(stub), args))
  expect_equal(r1, r2)
  expect_equal(r2, r3)
})

# ---------------------------------------------------------------------------
# 8. Bad selectors report the source (URL) and the offending field
# ---------------------------------------------------------------------------
test_that("malformed CSS reports the source and field", {
  err <- tryCatch(
    run_scraper(stub,
      Url = "http://example.test/a",
      CssPatterns = c(".author", "!!! bad", ".body"),
      PatternsName = c("author", "date", "body"),
      ContainerCssPat = ".comment"),
    error = identity)
  expect_match(conditionMessage(err), "http://example.test/a")
  expect_match(conditionMessage(err), "field 2")
  expect_match(conditionMessage(err), "!!! bad")

  err_c <- tryCatch(
    run_scraper(stub,
      HTmlText = html_a,
      CssPatterns = ".author",
      ContainerCssPat = ":::nope"),
    error = identity)
  expect_match(conditionMessage(err_c), "container")
  expect_match(conditionMessage(err_c), "HTmlText")
})

test_that("malformed XPath reports the source and field", {
  err <- tryCatch(
    run_scraper(stub,
      Url = "http://example.test/a",
      XpathPatterns = c("//*[contains(@class,'author')]", "//div["),
      PatternsName = c("author", "date"),
      ContainerXpathPat = "//div[@class='comment']"),
    error = identity)
  expect_match(conditionMessage(err), "http://example.test/a")
  expect_match(conditionMessage(err), "field 2")
  expect_match(conditionMessage(err), "//div[", fixed = TRUE)
})

test_that("a failed URL fetch in grouped mode names the URL", {
  err <- tryCatch(
    run_scraper(stub,
      Url = "http://example.test/missing",
      CssPatterns = ".author",
      ContainerCssPat = ".comment"),
    error = identity)
  expect_match(conditionMessage(err), "http://example.test/missing")
  expect_match(conditionMessage(err), "404")
})

# ---------------------------------------------------------------------------
# 9. astext = FALSE returns outer HTML, still aligned
# ---------------------------------------------------------------------------
test_that("astext=FALSE returns outer HTML per card", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".body"),
    PatternsName = c("author", "body"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"),
    astext = FALSE)
  expect_match(out$body[1], "^<p class=\"body\">")
  expect_true(is.na(out$body[3]))
})

# ---------------------------------------------------------------------------
# 10. No matching container -> zero rows but declared columns survive
# ---------------------------------------------------------------------------
test_that("page without cards yields a zero-row frame with the columns", {
  out <- run_scraper(stub,
    HTmlText = "<html><body><p>nothing here</p></body></html>",
    CssPatterns = c(".author", ".date"),
    PatternsName = c("author", "date"),
    ContainerCssPat = ".comment")
  expect_s3_class(out, "data.frame")
  expect_equal(names(out), c("author", "date"))
  expect_equal(nrow(out), 0)
})

# ---------------------------------------------------------------------------
# 11. Legacy behaviour is unchanged when no container is supplied
# ---------------------------------------------------------------------------
test_that("legacy vector output is unchanged without a container pattern", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date"),
    PatternsName = c("author", "date"),
    ManyPerPattern = TRUE,
    ExcludeCSSPat = ".ads")

  expect_type(out, "list")
  expect_false(inherits(out, "data.frame"))
  expect_named(out, c("author", "date"))
  # legacy ManyPerPattern returns plain character vectors per pattern
  expect_type(out$author, "character")
  expect_true(length(out$author) >= 3)
})

test_that("legacy single-match and data.frame paths still work", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c("h1", ".author"),
    PatternsName = c("title", "first_author"))
  expect_type(out, "list")
  expect_equal(out$title, "Discussion A")
  expect_equal(out$first_author, "Alice")

  df <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c("h1", ".author"),
    PatternsName = c("title", "first_author"),
    asDataFrame = TRUE)
  expect_s3_class(df, "data.frame")
})

# ---------------------------------------------------------------------------
# 12. Argument validation
# ---------------------------------------------------------------------------
test_that("default column names are syntactic; errors keep raw selectors", {
  out <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c(".author", ".date"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))
  # dot-leading CSS classes are already valid R names, so they are kept
  expect_equal(names(out), c(".author", ".date"))

  out2 <- run_scraper(stub,
    HTmlText = html_a,
    CssPatterns = c("h1 em", "h1 span"),
    ContainerCssPat = ".comment",
    ExcludeCSSPat = c(".quote", ".ads"))
  # spaces are made syntactic and duplicates are disambiguated
  expect_equal(names(out2), c("h1.em", "h1.span"))

  err <- tryCatch(
    run_scraper(stub,
      HTmlText = html_a,
      XpathPatterns = "//div[",
      ContainerXpathPat = "//div[contains(@class,'comment')]"),
    error = identity)
  expect_match(conditionMessage(err), "field 1 ('//div[')", fixed = TRUE)
  expect_match(conditionMessage(err), "HTmlText")
})

test_that("mixed selector families and missing fields are rejected", {
  expect_error(
    run_scraper(stub, HTmlText = html_a, CssPatterns = ".a",
                ContainerXpathPat = "//div"),
    "same selector family")
  expect_error(
    run_scraper(stub, HTmlText = html_a,
                ContainerCssPat = ".comment",
                CssPatterns = ".a", ExcludeXpathPat = "//x"),
    "ExcludeXpathPat cannot be combined")
  expect_error(
    run_scraper(stub, HTmlText = html_a,
                ContainerXpathPat = "//div",
                ContainerCssPat = ".comment", XpathPatterns = "//a"),
    "not both")
})
