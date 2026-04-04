#' Load a WOA NetCDF file
#'
#' Load a WOA .nc file and select layers for a given statistical field. Wrapper
#' around `terra::rast()` + [woa_nc_extract()]. Returns SpatRaster with
#' standardized `{variable}_depth={value}` layer names.
#'
#' @param file_path Character. Path to a WOA .nc file.
#' @param field Character. Statistical field to select. Default `"an"`
#'   (objectively analyzed climatology).
#'
#' @returns SpatRaster with standardized depth layer names.
#' @export
woa_load_nc <- function(file_path, field = "an") {
  stop("Not yet implemented")
}

#' Summarise monthly WOA data across months
#'
#' Takes a directory of monthly WOA .nc files, computes min/max/diff across
#' months at each depth. Works for any WOA variable (temperature, dissolved
#' oxygen, salinity, etc.).
#'
#' @param monthly_dir Character. Path to directory containing monthly WOA .nc
#'   files.
#' @param field Character. Statistical field to select. Default `"an"`.
#'
#' @returns Named list of SpatRasters: min, max, diff.
#' @export
woa_summarise_monthly <- function(monthly_dir, field = "an") {
  stop("Not yet implemented")
}

# TODO: create utils for downloading WOD data