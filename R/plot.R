#' Plot environmental depth profile for a species
#'
#' Plot environmental variable (e.g., temperature, dissolved oxygen) as a
#' vertical depth profile within a species range. Line plot with depth on
#' y-axis (inverted).
#'
#' @param species_name Character. Species name for the plot title.
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following the
#'   `{variable}_depth={value}` convention.
#' @param min_depth Numeric. Upper depth limit (metres).
#' @param max_depth Numeric. Lower depth limit (metres).
#'
#' @returns A ggplot object.
#' @export
plot_depth_profile <- function(species_name, rast_3d, min_depth, max_depth) {
  stop("Not yet implemented")
}

#' Plot species range at a specific depth layer
#'
#' Map view of a species range with environmental variable values at a specific
#' depth layer.
#'
#' @param species_range sf or SpatVector. Species range polygon.
#' @param depth Numeric. Depth (metres) at which to display environmental data.
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following the
#'   `{variable}_depth={value}` convention.
#'
#' @returns A ggplot object.
#' @export
plot_range_at_depth <- function(species_range, depth, rast_3d) {
  stop("Not yet implemented")
}

#' Plot 3D volume overlap between two ranges
#'
#' Map view of per-cell 3D volume overlap between two rasterized ranges (output
#' of [calc_volume_overlap()]). Cells colored by overlap depth.
#'
#' @param overlap_rast SpatRaster. Per-cell overlap raster from
#'   [calc_volume_overlap()].
#'
#' @returns A ggplot object.
#' @export
plot_volume_overlap <- function(overlap_rast) {
  stop("Not yet implemented")
}

#' Plot cumulative fishing pressure on a species
#'
#' Map showing cumulative fishing pressure from all sub-fisheries on a given
#' species. Cells colored by number of overlapping fisheries.
#'
#' @param species_rast SpatRaster. Rasterized species range from
#'   [rasterize_range()].
#' @param fishery_rasters List of SpatRasters. Rasterized fishery footprints
#'   from [rasterize_range()].
#'
#' @returns A ggplot object.
#' @export
plot_cumulative_pressure <- function(species_rast, fishery_rasters) {
  stop("Not yet implemented")
}

#' Plot overlap by depth across fisheries
#'
#' Bar or circular plot comparing 3D overlap percentage across sub-fisheries
#' for a species, with depth breakdown.
#'
#' @param species_name Character. Species name for the plot title.
#' @param fishery_names Character vector. Names of the sub-fisheries.
#' @param overlap_results List or tibble. Overlap results from
#'   [calc_volume_overlap()] applied across fisheries.
#'
#' @returns A ggplot object.
#' @export
plot_overlap_by_depth <- function(species_name, fishery_names,
                                  overlap_results) {
  stop("Not yet implemented")
}
