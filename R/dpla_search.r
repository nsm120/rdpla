#' Search metadata from the Digital Public Library of America (DPLA).
#'
#' @import httr jsonlite plyr assertthat
#' @export
#' @param q Query terms.
#' @param limit Number of items to return, defaults to 10. Max of 100.
#' @param page Page number to return, defaults to NULL.
#' @param sort_by The default sort order is ascending. Most, but not all fields
#'    can be sorted on. Attempts to sort on an un-sortable field will return
#'    the standard error structure with a HTTP 400 status code.
#' @param fields A vector of the fields to return in the output. The default
#'    is all fields. See details for options.
#' @param date.before Date before
#' @param date.after Date after
#' @param verbose If TRUE, fun little messages print to console to inform you
#'    of things.
#' @param callopts Curl options passed on to httr::GET
#' @details Options for the fields argument are:
#' \itemize{
#'  \item sourceResource.title The title of the object
#'  \item sourceResource.decription The description of the object
#'  \item sourceResource.subject The subjects of the object
#'  \item sourceResource.creator The creator of the object
#'  \item sourceResource.type The type of the object
#'  \item sourceResource.publisher The publisher of the object
#'  \item sourceResource.format The format of the object
#'  \item sourceResource.rights The rights for the object
#'  \item sourceResource.contributor The contributor of the object
#'  \item sourceResource.spatial The spatial of the object
#'  \item isPartOf The isPartOf thing, not sure what this is
#'  \item provider The provider of the object
#'  \item id The item id
#' }
#' @return A data.frame of results.
#' @examples \dontrun{
#' # Basic search, "fruit" in any fields
#' dpla_search(q="fruit")
#'
#' # Some verbosity
#' dpla_search(q="fruit", verbose=TRUE, limit=2)
#'
#' # Return certain fields
#' dpla_search(q="fruit", verbose=TRUE, fields=c("publisher","format"))
#' dpla_search(q="fruit", fields="subject")
#'
#' # Max is 100 per call, but the function handles larger numbers by looping
#' dpla_search(q="fruit", fields="id", limit=200)
#' dpla_search(q="fruit", fields=c("id","provider"), limit=200)
#' dpla_search(q="fruit", fields=c("id","provider"), limit=200)
#' out <- dpla_search(q="science", fields=c("id","subject"), limit=400)
#' head(out)
#'
#' # Search by date
#' dpla_search(q="science", date.before=1900, limit=200)
#'
#' # Spatial search
#' dpla_search(q='Boston', fields='spatial')
#' }

dpla_search <- function(q=NULL, verbose=FALSE, fields=NULL, limit=10, page=NULL,
  sort_by=NULL, date.before=NULL, date.after=NULL, callopts=list())
{
  fields2 <- fields

  if(!is.null(fields)){
    fieldsfunc <- function(x){
      if(x %in% c("title","description","subject","creator","type","publisher",
                  "format","rights","contributor","spatial")) {
        paste("sourceResource.", x, sep="") } else { x }
    }
    fields <- paste(sapply(fields, fieldsfunc, USE.NAMES=FALSE), collapse=",")
  } else {NULL}

  url <- "http://api.dp.la/v2/items"
  key <- getOption("dplakey")

  if(!limit > 100){
    args <- dcomp(list(api_key=key, q=q, page_size=limit, page=page, fields=fields,
                         sourceResource.date.before=date.before,
                         sourceResource.date.after=date.after))
    tt <- GET(url, query = args, callopts)
    warn_for_status(tt)
    assert_that(tt$headers$`content-type` == "application/json; charset=utf-8")
    res <- content(tt, as = "text")
    temp <- jsonlite::fromJSON(res, FALSE)
    hi <- data.frame(temp[1:3])
    if(verbose)
      message(paste(hi$count, " objects found, started at ", hi$start, ", and returned ", hi$limit, sep=""))
    dat <- temp[[4]] # collect data
  } else
  {
    maxpage <- ceiling(limit/100)
    page_vector <- seq(1,maxpage,1)
    argslist <- lapply(page_vector, function(x) dcomp(list(api_key=key, q=q, page_size=100, page=x, fields=fields, sourceResource.date.before=date.before, sourceResource.date.after=date.after)))
    out <- lapply(argslist, function(x){
      tt <- GET(url, query = x)
      warn_for_status(tt)
      assert_that(tt$headers$`content-type` == "application/json; charset=utf-8")
      res <- content(tt, as = "text")
      jsonlite::fromJSON(res, FALSE)
    })
    hi <- data.frame(out[[1]][1:3], out[[length(out)]][1:3])
    if(verbose)
      message(paste(hi$count, " objects found, started at ", hi$start, ", and returned ", sum(hi[,c(5,6)]), sep=""))
    dat <- do.call(c, lapply(out, function(x) x[[4]])) # collect data
  }

#   output <- ldply(dat, getdata)
  output <- do.call(rbind.fill, lapply(dat, getdata, flds=fields))

  if(is.null(fields)){ output  } else
    {
      output2 <- output[,names(output) %in% fields2]
      # convert one column factor string to data.frame (happens when only one field is requested)
      if(class(output2) %in% "factor"){
        output3 <- data.frame(output2)
        names(output3) <- fields2
        output3
      } else { output2 }
    }
}

# function to process data for each element
getdata <- function(y, flds){
  process_res <- function(x){
    id <- x$id
    title <- x$title
    description <- x$description
    subject <- if(length(x$subject)>1){paste(as.character(unlist(x$subject)), collapse=";")} else {x$subject[[1]][["name"]]}
    language <- x$language[[1]][["name"]]
    format <- x$format
    collection <- if(any(names(x$collection) %in% "name")) {x$collection[["name"]]} else {"no collection name"}
    type <- x$type
    date <- x$date[[1]]
    publisher <- x$publisher
    provider <- x$provider[["name"]]
    creator <- if(length(x$creator)>1){paste(as.character(x$creator), collapse=";")} else {x$creator}
    rights <- x$rights

    replacenull <- function(y){ ifelse(is.null(y), "no content", y) }
    ents <- list(id,title,description,subject,language,format,collection,type,provider,publisher,creator,rights,date)
    names(ents) <- c("id","title","description","subject","language","format","collection","type","provider","publisher","creator","rights","date")
    ents <- lapply(ents, replacenull)
    data.frame(ents, stringsAsFactors = FALSE)
  }
  if(is.null(flds)){
    id <- y$id
    provider <- data.frame(t(y$provider), stringsAsFactors = FALSE)
    names(provider) <- c("provider_url","provider_name")
    score <- y$score
    url <- y$isShownAt
    sourceResource <- y$sourceResource
    sourceResource_df <- process_res(sourceResource)
    sourceResource_df <- sourceResource_df[,!names(sourceResource_df) %in% c("id","provider")]
    data.frame(id, sourceResource_df, provider, score, url)
  } else
  {
    names(y) <- str_replace_all(names(y), "sourceResource.", "")
    if(length(y)==1) {
      onetemp <- list(y[[1]])
      onename <- names(y)
      names(onetemp) <- eval(onename)
      process_res(onetemp)
    } else
    { process_res(y) }
  }
}
