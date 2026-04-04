#' Load species range polygons
#'
#' Load species range polygons from IUCN shapefile or
#' `chondrichthyes.species.ranges` package. Filter by presence/origin/seasonal
#' codes, dissolve multipolygons per species.
#'
#' @param source Character. Path to IUCN shapefile or "package" to use
#'   `chondrichthyes.species.ranges`.
#' @param ids Character or numeric vector. Species identifiers to filter
#'   (scientific names or SIS IDs).
#'
#' @returns sf object with columns: id, scientific_name, geometry.
#' @export
load_species_ranges <- function(source, ids) {
  stop("Not yet implemented")
}

#' Fetch species depth limits from IUCN Red List API
#'
#' Query IUCN Red List API for upper/lower depth limits per species.
#'
#' @param api_key Character. IUCN Red List API token.
#' @param species_ids Character or numeric vector. Species identifiers (SIS IDs
#'   or scientific names).
#'
#' @returns Tibble with columns: sis_id, scientific_name, upper_depth_limit,
#'   lower_depth_limit.
#' @export
fetch_species_depths <- function(api_key, species_ids) {
  stop("Not yet implemented")
}

#' Fill missing depth values
#'
#' Fill NA depth values using genus-level means (or other method). Handles
#' swapped upper/lower values.
#'
#' @param depth_table Tibble. Output from [fetch_species_depths()] with
#'   possible NA values in depth columns.
#' @param method Character. Method for filling missing values. Default
#'   `"genus_mean"`.
#'
#' @returns Complete depth table with no NA depth values.
#' @export
fill_missing_depths <- function(depth_table, method = "genus_mean") {
  stop("Not yet implemented")
}

#' Load bathymetry raster
#'
#' Load a bathymetry raster from GEBCO that is in netCDF format. 
#'
#' @param file_path Character. Path to GEBCO bathymetry raster netCDF file.
#'
#' @returns SpatRaster.
#' @export
load_bathymetry <- function(file_path) {
  stop("Not yet implemented")
}
