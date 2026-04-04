#' Extract raster values from a 3D volume
#'
#' Crop a multi-depth SpatRaster to an area polygon and select depth layers
#' within range. Uses the `{variable}_depth={value}` layer naming convention to
#' determine which depth layers to select.
#'
#' Generalized from [woa_volume_extract()] — works with any multi-depth
#' SpatRaster, not just WOA data.
#'
#' @param area sf or SpatVector. Area polygon to crop the raster to.
#' @param min_depth Numeric. Minimum depth (metres).
#' @param max_depth Numeric. Maximum depth (metres).
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following the
#'   `{variable}_depth={value}` convention.
#'
#' @returns SpatRaster cropped to area and filtered to depth range.
#' @export
extract_rast_volume <- function(area, min_depth, max_depth, rast_3d) {
  stop("Not yet implemented")
}

#' Summarise environmental conditions within a species' 3D range
#'
#' Takes one species range + depth limits + named list of multi-depth
#' SpatRasters. Extracts and summarises each raster (extreme min/max, mean,
#' cell counts). Apply across species with `mapply()`/`lapply()` in vignettes.
#'
#' @param species_range sf or SpatVector. Single species range polygon.
#' @param min_depth Numeric. Upper depth limit (metres).
#' @param max_depth Numeric. Lower depth limit (metres).
#' @param raster_list Named list of SpatRasters. Each element is a multi-depth
#'   raster following the `{variable}_depth={value}` layer naming convention.
#'
#' @returns Single-row tibble with summary statistics for each raster in
#'   `raster_list`.
#' @export
summarise_species_environment <- function(species_range, min_depth, max_depth,
                                          raster_list) {
  stop("Not yet implemented")
}
