% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/getSummary.R
\docType{methods}
\name{getSummary,.FastqcFile-method}
\alias{getSummary,.FastqcFile-method}
\alias{getSummary}
\alias{getSummary,ANY-method}
\alias{getSummary,FastqcData-method}
\alias{getSummary,FastqcDataList-method}
\title{Get the summary information from Fastqc Files}
\usage{
\S4method{getSummary}{.FastqcFile}(object)

\S4method{getSummary}{ANY}(object)

\S4method{getSummary}{FastqcData}(object)

\S4method{getSummary}{FastqcDataList}(object)
}
\arguments{
\item{object}{Can be a \code{FastqcData}, \code{FastqcDataList} object or
a vector of paths to unparsed FastQC reports.}
}
\value{
A \code{tibble} containing the PASS/WARN/FAIL status for each
module, as defined in a FastQC report.
}
\description{
Read the information from the \code{summary.txt} files in each
.FastqcFile
}
\details{
This simply extracts the summary of PASS/WARN/FAIL status for every module
as defined by the tool FastQC for each supplied file.
}
\examples{

# Get the files included with the package
packageDir <- system.file("extdata", package = "ngsReports")
fl <- list.files(packageDir, pattern = "fastqc.zip", full.names = TRUE)

# Load the FASTQC data as a FastqcDataList object
fdl <- FastqcDataList(fl)

# Return a tibble/tibble with the raw information
getSummary(fdl)

}
