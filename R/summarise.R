#' Summarise across temporal dimension
#' 
#' Summarise multiple netCDF files across their temporal
#' dimension while preserving all non-temporal dimensions (for example
#' longitude, latitude, depth, or projected x/y dimensions).
#' 
#' @param file_paths Character vector. Paths to one or more Copernicus netCDF
#'   (`.nc` or `.nc4`) files.
#' @param fun Character vector of temporal summary statistics. Supported values
#'   are `"mean"`, `"min"`, `"max"`, and `"sd"`.
#' @param start_datetime Optional start datetime used to filter the available
#'   netCDF time steps before summarising. A `Date`, `POSIXt`, or character
#'   value interpreted in UTC.
#' @param end_datetime Optional end datetime. Defaults to `start_datetime` when
#'   only a start is supplied. If both are `NULL`, all available time steps are
#'   summarised.
#' @param output_dir Optional character. Directory in which summarised netCDF
#'   files are written. Defaults to the directory containing the first input
#'   file.
#' @param filename Optional character. Output filename. When multiple statistics
#'   are requested, the statistic is appended before the extension
#'   (for example `summary_mean.nc`, `summary_max.nc`).
#' @param na.rm Logical. If `TRUE` (default), missing values are ignored within
#'   each grid cell/depth combination. If `FALSE`, any missing temporal value
#'   produces a missing summary value at that location.
#' @param force Logical. Overwrite existing summary files. Default `FALSE`.
#' @param quiet Logical. Suppress progress messages. Default `FALSE`.
#'
#' @returns Named character vector containing paths to the summarised netCDF
#'   files, with names corresponding to `fun`.
#' 
#' @export
temporal_summarise <- function(file_paths,
                                 fun = c("mean", "min", "max", "sd"),
                                 start_datetime = NULL,
                                 end_datetime = NULL,
                                 output_dir = NULL,
                                 filename = NULL,
                                 na.rm = TRUE,
                                 force = FALSE,
                                 quiet = FALSE) {
  # TODO: Implement generic function for summarising multiple netCDF
  # Copernicus Marine and World Ocean Atlas datasets. 
  stop("this function is yet to be implemented.")
}