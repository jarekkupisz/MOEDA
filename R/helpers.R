#' Determines if a vector should be cut when moedizing
#'
#' Determines if a vector should be cut. Confirms if it inherits a class
#' for which base::cut is implemented (cut.default uses is.numeric), then checks
#' if there are more unique values than cuts requested.
#'
#' @param x an atomic vector
#' @param cuts An integer scalar determining how many cuts will be performed
#'
#' @return A boolean scalar
#'
is_cuttable <- function(x, cuts) {

  .is_granular <- function() length(unique(x)) > cuts

  if(is.numeric(x)) return(.is_granular())

  cuttable_classes <-
    gsub("^cut\\.", "", utils::methods(base::cut)) %>% as.character()

  if(inherits(x, cuttable_classes)) return(.is_granular()) else FALSE
}
