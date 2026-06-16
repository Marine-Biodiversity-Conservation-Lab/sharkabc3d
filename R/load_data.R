#' Fill missing depth values
#'
#' Fix swapped upper/lower depth values and fill NAs using genus-level means.
#' Designed for use inside [dplyr::mutate()] — returns a two-column tibble
#' (`upper_depth` and `lower_depth`) that can be unpacked with `mutate()`.
#'
#' @param upper Numeric vector. Upper (shallower) depth limit values, possibly
#'   with NAs or swapped values.
#' @param lower Numeric vector. Lower (deeper) depth limit values, possibly
#'   with NAs or swapped values.
#' @param genus Character vector. Genus names, used to compute genus-level
#'   mean depths for filling NAs.
#' @param method Character. Method for filling missing values. Currently only
#'   `"genus_mean"` is supported. Default `"genus_mean"`.
#'
#' @returns A tibble with columns `upper_depth` and `lower_depth`, suitable
#'   for use with [dplyr::mutate()].
#'
#' @examples
#' \dontrun{
#' species_info <- species_info %>%
#'   mutate(fill_missing_depths(upper_depth_limit, lower_depth_limit, genus_name))
#' }
#' @export
fill_missing_depths <- function(upper, lower, genus, method = "genus_mean") {
  if (method != "genus_mean") {
    stop("Only method = 'genus_mean' is currently supported.")
  }

  # Fix swapped values (upper should be shallower, i.e. smaller)
  swapped <- !is.na(upper) & !is.na(lower) & upper > lower
  tmp <- upper[swapped]
  upper[swapped] <- lower[swapped]
  lower[swapped] <- tmp

  # Per-genus means, broadcast back to each input row in place
  genus_mean <- function(x) stats::ave(x, genus,
                                       FUN = function(v) mean(v, na.rm = TRUE))

  data.frame(
    upper_depth = ifelse(is.na(upper), genus_mean(upper), upper),
    lower_depth = ifelse(is.na(lower), genus_mean(lower), lower)
  )
}

#' Load bathymetry raster
#'
#' Load a GEBCO bathymetry raster from a NetCDF file using [terra::rast()].
#' Validates that the file is NetCDF format, contains an `elevation` variable,
#' and has global extent (-180 to 180, -90 to 90). Values are returned as-is
#' (GEBCO uses negative values for below sea level).
#'
#' @param file_path Character. Path to GEBCO bathymetry NetCDF file (e.g.,
#'   `"gebco_2025_sub_ice_topo/GEBCO_2025_sub_ice.nc"`).
#'
#' @returns SpatRaster with elevation values in metres.
#' @export
load_bathymetry <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }

  # Check file extension is .nc
  if (!grepl("\\.nc$", file_path, ignore.case = TRUE)) {
    stop("Expected a NetCDF (.nc) file, got: ", basename(file_path))
  }

  bathy <- terra::rast(file_path)

  # Check variable name is "elevation"
  if (!("elevation" %in% terra::varnames(bathy))) {
    stop(
      "Expected variable 'elevation' in NetCDF, found: ",
      paste(terra::varnames(bathy), collapse = ", ")
    )
  }

  # Check global extent (-180 to 180, -90 to 90)
  e <- as.vector(terra::ext(bathy))
  if (e[1] != -180 || e[2] != 180 || e[3] != -90 || e[4] != 90) {
    stop(
      "Expected global extent (-180, 180, -90, 90), got: (",
      paste(e, collapse = ", "), ")"
    )
  }

  bathy
}
