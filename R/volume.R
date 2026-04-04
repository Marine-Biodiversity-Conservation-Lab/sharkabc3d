#' Rasterize a species range or fishery footprint onto a bathymetry grid
#'
#' Rasterize species range or fishery footprint onto the bathymetry grid.
#' Returns multi-layer SpatRaster with: presence (1/0), depth_min, depth_max
#' (clamped to bathymetry per cell so depth_max never exceeds seafloor).
#'
#' @param polygons sf or SpatVector. Species range or fishery footprint
#'   polygons.
#' @param bathymetry SpatRaster. Bathymetry raster (e.g., from
#'   [load_bathymetry()]).
#' @param depth_min Numeric. Minimum depth (metres) of the range.
#' @param depth_max Numeric. Maximum depth (metres) of the range.
#'
#' @returns Multi-layer SpatRaster with layers: presence, depth_min, depth_max.
#' @export
rasterize_range <- function(polygons, bathymetry, depth_min, depth_max) {
  stop("Not yet implemented")
}

#' Calculate total 3D volume of a rasterized range
#'
#' Volume = sum of (cell_area x (depth_max - depth_min)) across all present
#' cells.
#'
#' @param range_rast SpatRaster. Output from [rasterize_range()], with layers:
#'   presence, depth_min, depth_max.
#'
#' @returns Numeric. Total volume in km³.
#' @export
calc_volume <- function(range_rast) {
  stop("Not yet implemented")
}

#' Calculate 3D volume overlap between two rasterized ranges
#'
#' Per-cell depth overlap = min(max_a, max_b) - max(min_a, min_b), clamped to
#' 0. Bathymetry is already applied in [rasterize_range()].
#'
#' @param range_rast_a SpatRaster. First rasterized range (output of
#'   [rasterize_range()]).
#' @param range_rast_b SpatRaster. Second rasterized range (output of
#'   [rasterize_range()]).
#'
#' @returns List with:
#'   - `overlap_rast`: SpatRaster of per-cell overlap depth.
#'   - `summary`: Tibble with overlap_volume_km3, proportion_of_a,
#'     proportion_of_b.
#' @export
calc_volume_overlap <- function(range_rast_a, range_rast_b) {
  stop("Not yet implemented")
}
