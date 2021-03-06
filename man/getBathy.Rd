% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/lake_attribute_functions.R
\name{getBathy}
\alias{getBathy}
\title{Get Hypsometry for a given lake}
\usage{
getBathy(site_id)
}
\arguments{
\item{site_id}{The character ID for the requested data}
}
\value{
Data frame with columns \code{depth} and \code{area}
}
\description{
Returns the hypsometry profile for a lake with the given ID
}
\author{
Luke Winslow, Jordan Read
}
