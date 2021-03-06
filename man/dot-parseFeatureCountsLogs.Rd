% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/importNgsLogs.R
\name{.parseFeatureCountsLogs}
\alias{.parseFeatureCountsLogs}
\title{Parse data from featureCounts summary files}
\usage{
.parseFeatureCountsLogs(data, ...)
}
\arguments{
\item{data}{List of lines read using readLines on one or more files}

\item{...}{Not used
Can be 1:4, "sequences", "settings", "statistics" or "distribution"}
}
\value{
tibble
}
\description{
Parse data from featureCounts summary files
}
\details{
Checks for structure will have been performed
}
\keyword{internal}
