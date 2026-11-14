# Grouped (card-level) extraction engine for ContentScraper.
#
# In grouped mode a container/card selector splits the page into records:
# each matched card produces one row, every field selector is evaluated
# relative to that card, missing fields become NA and nested ads/quotes
# are removed structurally (node removal instead of the legacy
# fixed-string gsub). This file is only used when ContentScraper
# receives a ContainerXpathPat/ContainerCssPat argument; the legacy
# vector behaviour is untouched.

#' Translate one CSS selector to an XPath expression.
#' On failure an error carrying the source (URL) and the offending
#' field is raised.
#'
#' @keywords internal
#' @noRd
GroupedCssToXpath <- function(css, fieldLabel, sourceLabel) {
  tryCatch(
    selectr::css_to_xpath(css, prefix = "//"),
    error = function(e) {
      stop(sprintf("Invalid CSS selector for %s (source: %s): '%s' (%s)",
                   fieldLabel, sourceLabel, css, conditionMessage(e)),
           call. = FALSE)
    }
  )
}

#' Turn a document-scope (//-prefixed) XPath into a descendant-relative
#' query usable on a card node, so a field can only match inside its own
#' card and never borrow a value from a sibling. Absolute paths are left
#' untouched (the user explicitly asked for a document-absolute query).
#'
#' @keywords internal
#' @noRd
GroupedRelativeXpath <- function(xpath) {
  if (startsWith(xpath, "//")) paste0(".", xpath) else xpath
}

#' Validate an XPath expression against a document. xml2 only warns on
#' malformed XPath and returns an empty nodeset, so promote the warning
#' to an error carrying the source (URL) and the offending field.
#'
#' @keywords internal
#' @noRd
GroupedValidateXpath <- function(doc, xpath, fieldLabel, sourceLabel) {
  tryCatch(
    withCallingHandlers(
      xml2::xml_find_all(doc, xpath),
      warning = function(w) {
        stop(sprintf("Invalid XPath expression for %s (source: %s): '%s' (%s)",
                     fieldLabel, sourceLabel, xpath, conditionMessage(w)),
             call. = FALSE)
      }
    ),
    error = function(e) {
      msg <- conditionMessage(e)
      if (grepl("Invalid (CSS selector|XPath expression) for", msg)) {
        stop(msg, call. = FALSE)
      }
      stop(sprintf("Invalid XPath expression for %s (source: %s): '%s' (%s)",
                   fieldLabel, sourceLabel, xpath, msg),
           call. = FALSE)
    }
  )
  invisible(TRUE)
}

#' Extract one field value from a single card node.
#' Returns NA_character_ when the field is absent; because the query is
#' scoped to this card it can never return a sibling card's value.
#'
#' @keywords internal
#' @noRd
GroupedExtractField <- function(card, xpath, astext) {
  node <- tryCatch(
    xml2::xml_find_first(card, xpath),
    warning = function(w) {
      stop(sprintf("Invalid XPath expression: '%s' (%s)",
                   xpath, conditionMessage(w)), call. = FALSE)
    }
  )
  if (inherits(node, "xml_missing") || length(node) == 0) {
    return(NA_character_)
  }
  if (astext) {
    value <- xml2::xml_text(node)
    if (length(value) == 0 || is.na(value)) return(NA_character_)
    return(trimws(value))
  }
  as.character(node)
}

#' Resolve every user-supplied selector (container, fields, excludes) to
#' XPath, raising contextual errors for malformed CSS up front.
#'
#' @keywords internal
#' @noRd
GroupedResolvePatterns <- function(container, patterns, excludes,
                                   useCss, sourceLabel) {
  if (useCss) {
    containerXp <- GroupedCssToXpath(container, "container", sourceLabel)
    fieldXp <- vapply(seq_along(patterns), function(i) {
      GroupedCssToXpath(patterns[[i]],
                        sprintf("field %d ('%s')", i, patterns[[i]]),
                        sourceLabel)
    }, character(1))
    exclXp <- if (length(excludes) == 0) character(0) else
      vapply(seq_along(excludes), function(i) {
        GroupedCssToXpath(excludes[[i]],
                          sprintf("exclusion %d ('%s')", i, excludes[[i]]),
                          sourceLabel)
      }, character(1))
  } else {
    containerXp <- container
    fieldXp <- patterns
    exclXp <- excludes
  }
  list(container = containerXp, fields = fieldXp, excludes = exclXp)
}

#' Scrape one parsed document in grouped mode.
#'
#' Exclusion nodes are detached from the document before cards are
#' enumerated: nested ads/quotes disappear structurally, and a nested
#' container living inside a quote is removed together with the quote,
#' so it can never emit a stray record. Each remaining card is then
#' extracted independently.
#'
#' @param doc xml2 document
#' @param containerXpath XPath selecting the card containers
#' @param fieldXpaths character vector of field XPaths (document-scope,
#'   //-prefixed); made relative to each card internally
#' @param excludeXpaths character vector of exclusion XPaths, applied
#'   structurally before card enumeration
#' @param astext strip tags and return text, otherwise outer HTML
#' @param fieldNames column names, in declared order
#' @param fieldLabels raw selectors (or PatternsName) used in error
#'   messages, parallel to fieldNames
#' @param sourceLabel URL or an HTmlText marker, used in error messages
#'
#' @return data.frame, one row per card, all-character columns, NA for
#'   missing fields. A document without any card still carries the
#'   declared columns (zero rows).
#'
#' @keywords internal
#' @noRd
GroupedScrapeDoc <- function(doc, containerXpath, fieldXpaths, excludeXpaths,
                             astext, fieldNames, fieldLabels, sourceLabel) {

  relativeFields <- vapply(fieldXpaths, GroupedRelativeXpath, character(1),
                           USE.NAMES = FALSE)

  # Fail fast, with source + field context, before any row is built.
  GroupedValidateXpath(doc, containerXpath, "container", sourceLabel)
  for (i in seq_along(relativeFields)) {
    GroupedValidateXpath(doc, relativeFields[[i]],
                         sprintf("field %d ('%s')", i, fieldLabels[[i]]),
                         sourceLabel)
  }
  for (ex in excludeXpaths) {
    GroupedValidateXpath(doc, ex, "exclusion", sourceLabel)
  }

  # Structural removal of nested ads / quotes. Detaching nodes mutates
  # only this document instance; every ContentScraper call parses a fresh
  # document, so repeated runs cannot accumulate side effects.
  for (ex in excludeXpaths) {
    bad <- xml2::xml_find_all(doc, ex)
    if (length(bad) > 0) xml2::xml_remove(bad)
  }

  cards <- xml2::xml_find_all(doc, containerXpath)

  rows <- vector("list", length(cards))
  for (ci in seq_along(cards)) {
    # Queries are scoped to the card, so each record only sees its own
    # subtree: a missing field stays NA instead of taking the sibling's
    # value, and nested cards that survived exclusion cannot leak upwards
    # (the outer card still gets only its own first matching field).
    values <- lapply(relativeFields, function(xp) {
      GroupedExtractField(cards[[ci]], xp, astext)
    })
    rows[[ci]] <- as.data.frame(values, stringsAsFactors = FALSE,
                                col.names = fieldNames, check.names = FALSE,
                                optional = TRUE)
  }

  if (length(rows) == 0) {
    empty <- as.data.frame(
      stats::setNames(replicate(length(fieldNames), NA_character_,
                                simplify = FALSE), fieldNames),
      stringsAsFactors = FALSE, check.names = FALSE, optional = TRUE)
    return(empty[0, , drop = FALSE])
  }

  out <- do.call(rbind, rows)
  colnames(out) <- fieldNames
  rownames(out) <- NULL
  out
}

#' Entry point shared by the HTmlText and Url branches of ContentScraper
#' so both inputs produce identical grouped results.
#'
#' @param html character, document source
#' @param encod optional encoding
#' @inheritParams GroupedScrapeDoc
#'
#' @keywords internal
#' @noRd
GroupedScrapeHtml <- function(html, encod, container, patterns, excludes,
                              useCss, astext, fieldNames, fieldLabels,
                              sourceLabel) {
  doc <- if (missing(encod) || is.null(encod)) {
    xml2::read_html(html)
  } else {
    xml2::read_html(html, encoding = encod)
  }

  if (astext) {
    # Mirrors the legacy path: script nodes never contribute visible text.
    invisible(xml2::xml_remove(xml2::xml_find_all(doc, "//script")))
  }

  resolved <- GroupedResolvePatterns(container, patterns, excludes,
                                     useCss, sourceLabel)
  GroupedScrapeDoc(doc, resolved$container, resolved$fields,
                   resolved$excludes, astext, fieldNames, fieldLabels,
                   sourceLabel)
}
