#' ContentScraper
#'
#' @param Url character, one url or a vector of urls of web pages to scrape.
#' @param HTmlText character, web page as HTML text to be scraped.use either Url or HtmlText not both.
#' @param XpathPatterns character vector, one or more XPath patterns to extract from the web page.
#' @param CssPatterns character vector, one or more CSS selector patterns to extract from the web page.
#' @param PatternsName character vector, given names for each xpath pattern to extract, just as an indication .
#' @param ManyPerPattern boolean, If False only the first matched element by the pattern is extracted (like in Blogs one page has one article/post and one title). Otherwise if set to True all nodes matching the pattern are extracted (Like in galleries, listing or comments, one page has many elements with the same pattern )
#' @param ExcludeXpathPat character vector, one or more Xpath pattern to exclude from extracted content (like excluding quotes from forum replies or excluding middle ads from Blog post) .
#' @param ExcludeCSSPat character vector, one or more Css pattern to exclude from extracted content.
#' @param astext boolean, default is TRUE, HTML and PHP tags is stripped from the extracted piece.
#' @param asDataFrame boolean, transform scraped data into a Dataframe. default is False (data is returned as List)
#' @param ContainerXpathPat character, one XPath pattern selecting the repeating card/container elements (e.g. a comment box, a review or a listing row). When supplied, the grouped extraction mode is enabled: each matched container produces one record, the other XpathPatterns are evaluated relatively to each container, fields are returned in their declared order and a field missing from a container becomes NA. Nested structures matched by ExcludeXpathPat (quotes, ads) are removed node-wise before extraction, so sibling containers cannot share or leak values. Grouped mode always returns a data.frame and is disabled unless a container pattern is provided.
#' @param ContainerCssPat character, same as ContainerXpathPat using a CSS selector. Use it together with CssPatterns and ExcludeCSSPat.
#' @param browser, a web driver session, or a loggedin session of the web driver (see examples)
#' @param encod character, set the weppage character encoding.
#' @return
#' return a named list of scraped content. When grouped extraction is enabled
#' (ContainerXpathPat/ContainerCssPat supplied) the return value is a
#' data.frame with one row per container and one column per pattern, in
#' declared order, with NA for missing fields; with several Urls the rows of
#' each page are appended in the input order.
#' @author salim khalil
#' @examples
#' \dontrun{
#'
#' #### Extract title, publishing date and article from the web page using css selectors
#' #
#' DATA<-ContentScraper(Url="http://glofile.com/index.php/2017/06/08/taux-nette-detente/",
#' CssPatterns = c(".entry-title",".published",".entry-content"), astext = TRUE)
#'
#' #### The web page source can be provided also in HTML text (characters)
#' #
#' txthml<-"<html><title>blah</title><div><p>I m the content</p></div></html>"
#' DATA<-ContentScraper(HTmlText = txthml ,XpathPatterns = "//*/p")
#'
#' #### Extract post title and bodt from the web page using Xpath patterns,
#' #  PatternsName can be provided as indication.
#' #
#' DATA<-ContentScraper(Url ="http://glofile.com/index.php/2017/06/08/athletisme-m-a-rome/",
#' XpathPatterns=c("//head/title","//*/article"),PatternsName=c("title", "article"))
#'
#' #### Extract titles and contents of 3 Urls using CSS selectors, As result DATA variable
#' # will handle 6 elements.
#' #
#' urllist<-c("http://glofile.com/index.php/2017/06/08/sondage-quel-budget/",
#' "http://glofile.com/index.php/2017/06/08/cyril-hanouna-tire-a-boulets-rouges-sur-le-csa/",
#' "http://glofile.com/index.php/2017/06/08/placements-quelles-solutions-pour-doper/",
#' "http://glofile.com/index.php/2017/06/08/paris-un-concentre-de-suspens/")
#' DATA<-ContentScraper(Url =urllist, CssPatterns = c(".entry-title",".entry-content"),
#' PatternsName = c("title","content"))
#'
#' #### Extract post title and list of comments from a set of blog pages,
#' # ManyPerPattern argument enables extracting many elements having same pattern from each
#' # page like comments, reviews, quotes and listing.
#' DATA<-ContentScraper(Url =urllist, CssPatterns = c(".entry-title",".comment-content p"),
#' PatternsName = c("title","comments"), astext = TRUE, ManyPerPattern = TRUE)

#' #### From this Forum page  e extract the post title and all replies using CSS selectors
#' # c("head > title",".post"), However, we know that each reply contain previous Replys
#' # as quote so we need to exclude To remove inner quotes in each reply we use
#' # ExcludeCSSPat c(".quote",".quoteheader a")
#' DATA<-ContentScraper(Url = "https://bitcointalk.org/index.php?topic=2334331.0",
#' CssPatterns = c("head > title",".post"), ExcludeCSSPat = c(".quote",".quoteheader"),
#' PatternsName = c("Title","Replys"), ManyPerPattern = TRUE)
#'
#' #### Grouped extraction: one record per comment card.
#' # Each .comment container becomes a row; author/date/body queries run
#' # inside its own subtree, a missing date is NA and nested quotes/ads are
#' # removed structurally instead of being stripped by string replacement.
#' DATA<-ContentScraper(Url = "https://example.org/comments",
#' CssPatterns = c(".author",".date",".body"),
#' PatternsName = c("author","date","body"),
#' ContainerCssPat = ".comment",
#' ExcludeCSSPat = c(".quote",".ads"))
#'
#' #### Scrape data from web page requiring authentification
#' # replace \@ by @ before running follwing examples
#' # create a loggedin session
#' LS<-run_browser()
#' LS<-LoginSession(Browser = LS, LoginURL = 'https://manager.submittable.com/login',
#'    LoginCredentials = c('your email','your password'),
#'    cssLoginFields =c('#email', '#password'),
#'    XpathLoginButton ='//*[\@type=\"submit\"]' )
#' #Then scrape data with the session
#' DATA<-ContentScraper(Url='https://manager.submittable.com/beta/discover/119087',
#'      XpathPatterns = c('//*[\@id=\"submitter-app\"]/div/div[2]/div/div/div/div/div[3]',
#'       '//*[\@id=\"submitter-app\"]/div/div[2]/div/div/div/div/div[2]/div[1]/div[1]' ),
#'       PatternsName = c("Article","Title"), astext = TRUE, browser = LS )
#' #OR
#' page<-LinkExtractor(url='https://manager.submittable.com/beta/discover/119087',
#'                     browser = LS)
#' DATA<-ContentScraper(HTmlText = page$Info$Source_page,
#'      XpathPatterns = c("//*[\@id=\"submitter-app\"]/div/div[2]/div/div/div/div/div[3]",
#'      "//*[\@id=\"submitter-app\"]/div/div[2]/div/div/div/div/div[2]/div[1]/div[1]" ),
#'       PatternsName = c("Article","Title"),astext = TRUE )
#'
#' To get all first elements of the lists in one vector (example all titles) :
#' VecTitle<-unlist(lapply(DATA, `[[`, 1))
#' To get all second elements of the lists in one vector (example all articles)
#' VecContent<-unlist(lapply(DATA, `[[`, 2))
#'
#' }
#' @importFrom  xml2 read_html
#' @importFrom  xml2 xml_find_all
#' @importFrom  xml2 xml_text
#' @importFrom  xml2 xml_find_first
#' @importFrom  xml2 xml_remove
#' @importFrom  selectr css_to_xpath
#' @export
#'
#'
ContentScraper <- function(Url, HTmlText, browser, XpathPatterns, CssPatterns, PatternsName,
                           ExcludeXpathPat, ExcludeCSSPat, ManyPerPattern=FALSE, astext=TRUE, asDataFrame=FALSE, encod,
                           ContainerXpathPat, ContainerCssPat) {

  if(!missing(Url) && !missing(HTmlText) ){
    stop("Please supply Url or HTmlText, not both !")
  }

  if(!missing(XpathPatterns) && !missing(CssPatterns) ){
    stop("Please supply XpathPatterns or CssPatterns, not both !")
  }

  if(!missing(ExcludeXpathPat) && !missing(ExcludeCSSPat) ){
    stop("Please supply ExcludeXpathPat or ExcludeCSSPat, not both !")
  }

  # Grouped (card-level) extraction mode, off by default: it activates only
  # when a container pattern is explicitly supplied.
  groupedMode <- !missing(ContainerXpathPat) || !missing(ContainerCssPat)
  if (groupedMode) {
    if (!missing(ContainerXpathPat) && !missing(ContainerCssPat)) {
      stop("Please supply ContainerXpathPat or ContainerCssPat, not both !")
    }
    if (missing(XpathPatterns) && missing(CssPatterns)) {
      stop("Grouped extraction requires field patterns (XpathPatterns or CssPatterns) in addition to the container pattern !")
    }
    if (!missing(ContainerCssPat) && missing(CssPatterns)) {
      stop("ContainerCssPat must be used with CssPatterns (the same selector family) !")
    }
    if (!missing(ContainerXpathPat) && missing(XpathPatterns)) {
      stop("ContainerXpathPat must be used with XpathPatterns (the same selector family) !")
    }
    if (!missing(ExcludeCSSPat) && !missing(XpathPatterns)) {
      stop("ExcludeCSSPat cannot be combined with XpathPatterns; use ExcludeXpathPat in grouped XPath mode !")
    }
    if (!missing(ExcludeXpathPat) && !missing(CssPatterns)) {
      stop("ExcludeXpathPat cannot be combined with CssPatterns; use ExcludeCSSPat in grouped CSS mode !")
    }
  }
  if(!missing(XpathPatterns) && !missing(PatternsName) ){
    if (length(XpathPatterns)!=length(PatternsName)) stop("PatternsName & XpathPatterns parameters must have the same length ")
  }
  if(!missing(CssPatterns) && !missing(PatternsName) ){
    if (length(CssPatterns)!=length(PatternsName)) stop("PatternsName & CssPatterns parameters must have the same length ")
  }

  if (groupedMode) {
    useCssGrouped <- !missing(ContainerCssPat)
    containerGrouped <- if (useCssGrouped) ContainerCssPat else ContainerXpathPat
    patternsGrouped <- if (useCssGrouped) CssPatterns else XpathPatterns
    excludesGrouped <- if (useCssGrouped) {
      if (missing(ExcludeCSSPat)) character(0) else ExcludeCSSPat
    } else {
      if (missing(ExcludeXpathPat)) character(0) else ExcludeXpathPat
    }
    if (!is.vector(patternsGrouped) || length(patternsGrouped) < 1) {
      stop("Grouped extraction requires at least one field pattern !")
    }
    fieldNamesGrouped <- if (!missing(PatternsName)) {
      PatternsName
    } else {
      make.names(patternsGrouped, unique = TRUE)
    }
    # Default column names are syntactic names; validation messages keep
    # the raw selector via a parallel label vector.
    fieldLabelsGrouped <- if (!missing(PatternsName)) {
      PatternsName
    } else {
      patternsGrouped
    }
  }

  if (groupedMode && missing(Url)) {
    # HTmlText entry: same engine as the Url entry, so both yield identical
    # results for the same document.
    return(GroupedScrapeHtml(
      html = HTmlText,
      encod = if (missing(encod)) NULL else encod,
      container = containerGrouped,
      patterns = patternsGrouped,
      excludes = excludesGrouped,
      useCss = useCssGrouped,
      astext = astext,
      fieldNames = fieldNamesGrouped,
      fieldLabels = fieldLabelsGrouped,
      sourceLabel = "HTmlText"
    ))
  }

  if (!groupedMode) {
    if(!missing(ExcludeCSSPat)) {
      if(is.vector(ExcludeCSSPat)){
        ExcludeXpathPat<- unlist(lapply(ExcludeCSSPat, FUN = function(x) { tryCatch(selectr::css_to_xpath(x, prefix = "//") ,error=function(e) stop("Unable to translate supplied css selector, Please check CssPatterns syntax !"))}))
      }
    }
    if(!missing(CssPatterns)) {
      if(is.vector(CssPatterns)){
        XpathPatterns<- unlist(lapply(CssPatterns, FUN = function(x) { tryCatch(selectr::css_to_xpath(x, prefix = "//") ,error=function(e) stop("Unable to translate supplied css selector, Please check CssPatterns syntax !"))}))
      } else {
        stop("CssPatterns parameter must be a vector with at least one element !")
      }
    }
  }

  content<-list()
  if(!missing(Url) && missing(HTmlText)){
    pos<-1
    for(Ur in Url){
      if(missing(browser)){
      pageinfo<-LinkExtractor(url=Ur, encod=encod)
      } else {
      pageinfo<-LinkExtractor(url=Ur, encod=encod, Browser = browser)
      }
      if(pageinfo$Info$Status_code==200){
          if (groupedMode) {
            # Same engine as the HTmlText entry; rows from successive URLs
            # are appended in input order below. Named access keeps this
            # branch independent of the legacy positional page layout.
            HTmlText<-pageinfo$Info$Source_page
            contentx <- GroupedScrapeHtml(
              html = HTmlText,
              encod = if (missing(encod)) NULL else encod,
              container = containerGrouped,
              patterns = patternsGrouped,
              excludes = excludesGrouped,
              useCss = useCssGrouped,
              astext = astext,
              fieldNames = fieldNamesGrouped,
              fieldLabels = fieldLabelsGrouped,
              sourceLabel = Ur
            )
          } else {
          x<-xml2::read_html(HTmlText, encoding = encod)
          if(ManyPerPattern){

        if (astext && (missing(ExcludeXpathPat)||is.null(ExcludeXpathPat))){
          invisible(xml2::xml_remove(xml_find_all(x, "//script")))
          contentx<-lapply(XpathPatterns,function(n) { tryCatch(xml2::xml_text(xml2::xml_find_all(x,n)),error=function(e) "NA" ) })

        }
        else{
          contentx<-lapply(XpathPatterns,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) "" ) })
        }
        if((!missing(ExcludeCSSPat) || !missing(ExcludeXpathPat))){
          if (!is.null(ExcludeXpathPat)){
            #contentx<-unlist(contentx)
            ToExcludeL<-lapply(ExcludeXpathPat,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) NULL ) })
            ToExclude<-unlist(ToExcludeL)
            if(!is.null(ToExclude) && length(ToExclude)>0 ){
              for( i in 1:length(ToExclude)) {
                for (j in 1:length(contentx)) {
                  if(length(contentx[[j]])>1){
                    for(k in 1:length(contentx[[j]])){
                      if (grepl(ToExclude[[i]], contentx[[j]][[k]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                        contentx[[j]][[k]]<-gsub(ToExclude[[i]],"", contentx[[j]][[k]], fixed = TRUE)
                      }
                    }
                  } else if(length(contentx[[j]])==1) {
                    if (grepl(ToExclude[[i]], contentx[[j]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                      contentx[[j]]<-gsub(ToExclude[[i]],"", contentx[[j]], fixed = TRUE)
                    }
                  }
                }
              }
            }
            if(astext){
              for (j in 1:length(contentx)) {
                if(length(contentx[[j]])>0){
                  for(k in 1:length(contentx[[j]])){
                    contentx[[j]][[k]]<-RemoveTags(contentx[[j]][[k]])
                  }
                }
              }
            }
          }
        }
        if(!missing(PatternsName)){
          for( i in 1:length(contentx)) {
            if(length(contentx[[i]])>0){
              names(contentx)[i]<-PatternsName[[i]]
            }
          }
        }

      }
          else {

        if (astext && (missing(ExcludeXpathPat) ||is.null(ExcludeXpathPat))){
          invisible(xml_remove(xml_find_all(x, "//script")))
          contentx<-lapply(XpathPatterns,function(n) { tryCatch(xml2::xml_text(xml_find_first(x,n)),error=function(e) "" ) })
        }
        else{
          contentx<-lapply(XpathPatterns,function(n) { tryCatch(paste(xml2::xml_find_first(x,n)),error=function(e) "" ) })
        }
        if(!missing(ExcludeCSSPat) || !missing(ExcludeXpathPat)){
          if(!is.null(ExcludeXpathPat)){
            #contentx<-unlist(contentx)
            ToExcludeL<-lapply(ExcludeXpathPat,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) NULL ) })
            ToExclude<-unlist(ToExcludeL)
            if(!is.null(ToExclude) && length(ToExclude)>0 ){
              for( i in 1:length(ToExclude)) {
                for (j in 1:length(contentx)) {
                  if(length(contentx[[j]])>1){
                    for(k in 1:length(contentx[[j]])){
                      if (grepl(ToExclude[[i]], contentx[[j]][[k]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                        contentx[[j]][[k]]<-gsub(ToExclude[[i]],"", contentx[[j]][[k]], fixed = TRUE)
                      }
                    }
                  } else if(length(contentx[[j]])==1) {
                    if (grepl(ToExclude[[i]], contentx[[j]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                      contentx[[j]]<-gsub(ToExclude[[i]],"", contentx[[j]], fixed = TRUE)
                    }
                  }
                }
              }
            }
            if(astext){
              for (j in 1:length(contentx)) {
                if(length(contentx[[j]])>0){
                  for(k in 1:length(contentx[[j]])){
                    contentx[[j]][[k]]<-RemoveTags(contentx[[j]][[k]])
                  }
                }
              }
            }
          }
        }
        if  (!missing(PatternsName)){
          for( i in 1:length(contentx)) {
            names(contentx)[i]<-PatternsName[[i]]
          }
        }

      }
      } # end of legacy (non-grouped) 200 branch
      } else {
        if (groupedMode) {
          # A failed fetch cannot produce aligned rows; report the URL so
          # the caller knows which page of the vector failed.
          stop(sprintf("Unable to scrape '%s' in grouped mode: HTTP error code: %s",
                       Ur, pageinfo$Info$Status_code), call. = FALSE)
        }
        contentx<- paste0("HTTP error code:",pageinfo$Info$Status_code)
      }
    if (groupedMode) {
      # Keep the input URL order; every page contributes the same columns.
      content <- if (length(content) == 0) contentx else rbind(content, contentx)
      rownames(content) <- NULL
    } else if(length(Url)>1) content<-c(content,list(contentx))
      else content<-c(content,contentx)

    cat(pos,"..", sep = "")
    pos<-pos+1
    flush.console()
    Sys.sleep(1)
    }
  }
  if(missing(Url) && !missing(HTmlText)){
    x<-xml2::read_html(HTmlText,  encoding= encod)
    if(ManyPerPattern){

      if (astext && (missing(ExcludeXpathPat)||is.null(ExcludeXpathPat))){
        invisible(xml2::xml_remove(xml_find_all(x, "//script")))
        contentx<-lapply(XpathPatterns,function(n) { tryCatch(xml2::xml_text(xml2::xml_find_all(x,n)),error=function(e) "NA" ) })

      }
      else{
        contentx<-lapply(XpathPatterns,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) "" ) })
      }
      if((!missing(ExcludeCSSPat) || !missing(ExcludeXpathPat))){
        if (!is.null(ExcludeXpathPat)){
          #contentx<-unlist(contentx)
          ToExcludeL<-lapply(ExcludeXpathPat,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) NULL ) })
          ToExclude<-unlist(ToExcludeL)
          if(!is.null(ToExclude) && length(ToExclude)>0 ){
            for( i in 1:length(ToExclude)) {
              for (j in 1:length(contentx)) {
                if(length(contentx[[j]])>1){
                  for(k in 1:length(contentx[[j]])){
                    if (grepl(ToExclude[[i]], contentx[[j]][[k]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                      contentx[[j]][[k]]<-gsub(ToExclude[[i]],"", contentx[[j]][[k]], fixed = TRUE)
                    }
                  }
                } else if(length(contentx[[j]])==1) {
                  if (grepl(ToExclude[[i]], contentx[[j]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                    contentx[[j]]<-gsub(ToExclude[[i]],"", contentx[[j]], fixed = TRUE)
                  }
                }
              }
            }
          }
          if(astext){
            for (j in 1:length(contentx)) {
              if(length(contentx[[j]])>0){
                for(k in 1:length(contentx[[j]])){
                  contentx[[j]][[k]]<-RemoveTags(contentx[[j]][[k]])
                }
              }
            }
          }
        }
      }
      if(!missing(PatternsName)){
        for( i in 1:length(contentx)) {
          if(length(contentx[[i]])>0){
            names(contentx)[i]<-PatternsName[[i]]
          }
        }
      }

    }
    else {

      if (astext && (missing(ExcludeXpathPat) ||is.null(ExcludeXpathPat))){
        invisible(xml_remove(xml_find_all(x, "//script")))
        contentx<-lapply(XpathPatterns,function(n) { tryCatch(xml2::xml_text(xml_find_first(x,n)),error=function(e) "" ) })
      }
      else{
        contentx<-lapply(XpathPatterns,function(n) { tryCatch(paste(xml2::xml_find_first(x,n)),error=function(e) "" ) })
      }
      if(!missing(ExcludeCSSPat) || !missing(ExcludeXpathPat)){
        if(!is.null(ExcludeXpathPat)){
          #contentx<-unlist(contentx)
          ToExcludeL<-lapply(ExcludeXpathPat,function(n) { tryCatch(paste(xml2::xml_find_all(x,n)),error=function(e) NULL ) })
          ToExclude<-unlist(ToExcludeL)
          if(!is.null(ToExclude) && length(ToExclude)>0 ){
            for( i in 1:length(ToExclude)) {
              for (j in 1:length(contentx)) {
                if(length(contentx[[j]])>1){
                  for(k in 1:length(contentx[[j]])){
                    if (grepl(ToExclude[[i]], contentx[[j]][[k]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                      contentx[[j]][[k]]<-gsub(ToExclude[[i]],"", contentx[[j]][[k]], fixed = TRUE)
                    }
                  }
                } else if(length(contentx[[j]])==1) {
                  if (grepl(ToExclude[[i]], contentx[[j]], fixed = TRUE) && nchar(ToExclude[[i]])!=0 ){
                    contentx[[j]]<-gsub(ToExclude[[i]],"", contentx[[j]], fixed = TRUE)
                  }
                }
              }
            }
          }
          if(astext){
            for (j in 1:length(contentx)) {
              if(length(contentx[[j]])>0){
                for(k in 1:length(contentx[[j]])){
                  contentx[[j]][[k]]<-RemoveTags(contentx[[j]][[k]])
                }
              }
            }
          }
        }
      }
      if  (!missing(PatternsName)){
        for( i in 1:length(contentx)) {
          names(contentx)[i]<-PatternsName[[i]]
        }
      }

    }
    content<-c(content,contentx)
  }


  if(asDataFrame){
    content<-data.frame(do.call("rbind", NormalizeForExcel(content)))
  }
  return (content)
}
