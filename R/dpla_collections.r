#' Search collections from the Digital Public Library of America (DPLA).
#'
#' @export
#'
#' @param q Query terms.
#' @param fields A vector of the fields to return in the output. The default
#' @param sort_by The default sort order is ascending. Most, but not all fields
#'    can be sorted on. Attempts to sort on an un-sortable field will return
#'    the standard error structure with a HTTP 400 status code.
#'    is all fields. See details for options.
#' @param limit Number of items to return, defaults to 10. Max of 100.
#' @param page Page number to return, defaults to NULL.
#' @param key Your DPLA API key. Either pass in here, or store in your \code{.Rprofile} file
#'    and it will be read in on function execution.
#' @param ... Curl options passed on to \code{\link[httr]{GET}}
#'
#' @return xxxx
#'
#' @examples \donttest{
#' dpla_collections(q="university")
#' dpla_collections(q="university of texas", limit=2)
#' dpla_collections(q="university of texas", fields='id', limit=2)
#' dpla_collections(q="university of texas", sort_by='title', limit=5)
#' }

dpla_collections <- function(q=NULL, fields=NULL, sort_by=NULL, limit=10, page=NULL,
  key=getOption("dplakey"), ...)
{
  args <- dcomp(list(api_key=key, q=q, page_size=limit, page=page, fields=fields, sort_by=sort_by))
  res <- dpla_GET(paste0(dpbase(), "collections"), args, ...)
  meta <- data.frame(found=res$count, returned=res$limit, stringsAsFactors = FALSE)
  dat <- do.call(rbind.fill, lapply(res$docs, parse_coll))
  list(meta=meta, data=dat)
}

parse_coll <- function(x){
  admin <- sapply(x$admin, ifn)
  x <- pop(x, "admin")
  df <- data.frame(lapply(x, ifn), stringsAsFactors = FALSE)
  names(df) <- as.character(names(x))
  cbind(df, t(admin))
}