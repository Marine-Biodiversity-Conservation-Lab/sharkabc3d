#' Calculate total 3D volume of a rasterized range
#'
#' Volume = sum of (cell_area x (depth_max - depth_min)) across all present
#' cells.
#'
#' @param range_rast SpatRaster. Output from [voxelize_range()], with layers:
#'   depth_min, depth_max.
#'
#' @returns Numeric. Total volume in km³.
#' @export
calc_volume <- function(range_rast) {
  depth_extent <- range_rast[["depth_max"]] - range_rast[["depth_min"]]

  # Cell area in km² (cellSize returns m² by default)
  cell_area_km2 <- terra::cellSize(range_rast[["depth_min"]], unit = "km")

  # Volume per cell in km³ (depth in m, convert to km)
  vol_rast <- cell_area_km2 * (depth_extent / 1000)

  terra::global(vol_rast, "sum", na.rm = TRUE)[[1]]
}

#' Calculate 3D volume overlap between two rasterized ranges
#'
#' Computes per-cell depth intervals and volumes for two ranges and their
#' intersection. Returns a 9-layer raster stack containing the depth limits
#' for each range and their overlap, plus the corresponding volumes. Cells
#' where a range is absent have NA for that range's layers. The intersection
#' layers are NA where the two depth intervals do not overlap.
#'
#' @param range_rast_a SpatRaster. First rasterized range (output of
#'   [voxelize_range()]).
#' @param range_rast_b SpatRaster. Second rasterized range (output of
#'   [voxelize_range()]).
#'
#' @returns Multi-layer SpatRaster with 9 layers:
#'   \describe{
#'     \item{depth_min_a, depth_max_a}{Depth limits of range A (m)}
#'     \item{depth_min_b, depth_max_b}{Depth limits of range B (m)}
#'     \item{depth_min_overlap, depth_max_overlap}{Depth limits of the
#'       intersection (m). NA where ranges do not overlap in depth.}
#'     \item{volume_a, volume_b}{Per-cell volume of each range (km³)}
#'     \item{volume_overlap}{Per-cell overlap volume (km³)}
#'   }
#' @export
calc_volume_overlap <- function(range_rast_a, range_rast_b) {
  cell_area_km2 <- terra::cellSize(range_rast_a[["depth_min"]], unit = "km")

  # Depth layers for A
  dmin_a <- range_rast_a[["depth_min"]]
  dmax_a <- range_rast_a[["depth_max"]]
  names(dmin_a) <- "depth_min_a"
  names(dmax_a) <- "depth_max_a"

  # Depth layers for B
  dmin_b <- range_rast_b[["depth_min"]]
  dmax_b <- range_rast_b[["depth_max"]]
  names(dmin_b) <- "depth_min_b"
  names(dmax_b) <- "depth_max_b"

  # Per-cell volume for A and B
  vol_a <- cell_area_km2 * ((dmax_a - dmin_a) / 1000)
  names(vol_a) <- "volume_a"
  vol_b <- cell_area_km2 * ((dmax_b - dmin_b) / 1000)
  names(vol_b) <- "volume_b"

  # Intersection depth interval (only where both present)
  both_present <- !is.na(dmin_a) & !is.na(dmin_b)
  both_mask <- terra::ifel(both_present, 1, NA)

  overlap_min <- terra::mask(terra::ifel(dmin_a > dmin_b, dmin_a, dmin_b), both_mask)
  overlap_max <- terra::mask(terra::ifel(dmax_a < dmax_b, dmax_a, dmax_b), both_mask)

  # Set to NA where depth intervals do not overlap
  has_overlap <- terra::ifel(overlap_max > overlap_min, 1, NA)
  overlap_min <- terra::mask(overlap_min, has_overlap)
  overlap_max <- terra::mask(overlap_max, has_overlap)
  names(overlap_min) <- "depth_min_overlap"
  names(overlap_max) <- "depth_max_overlap"

  # Overlap volume (0 where no depth overlap, NA where not both present)
  overlap_depth <- terra::clamp(overlap_max - overlap_min, lower = 0)
  overlap_depth <- terra::mask(overlap_depth, both_mask)
  # Replace NA with 0 for cells where both are present but don't overlap
  overlap_depth <- terra::ifel(is.na(overlap_depth) & both_present, 0, overlap_depth)
  vol_overlap <- cell_area_km2 * (overlap_depth / 1000)
  names(vol_overlap) <- "volume_overlap"

  c(dmin_a, dmax_a, dmin_b, dmax_b, overlap_min, overlap_max,
    vol_a, vol_b, vol_overlap)
}

#' Binary 3D overlap between two rasterized ranges
#'
#' Returns a single-layer raster that is `1` in cells where the two ranges
#' overlap both horizontally (both present) and vertically (their depth
#' intervals intersect), and `NA` otherwise. Thin wrapper around
#' [calc_volume_overlap()] for richness / tally maps where the per-cell
#' overlap volume is not needed.
#'
#' @param range_rast_a SpatRaster. First rasterized range (output of
#'   [voxelize_range()]).
#' @param range_rast_b SpatRaster. Second rasterized range (output of
#'   [voxelize_range()]).
#'
#' @returns Single-layer SpatRaster (`1` where the two ranges overlap in 3D,
#'   `NA` elsewhere).
#' @export
count_3d_overlap <- function(range_rast_a, range_rast_b) {
  ov <- calc_volume_overlap(range_rast_a, range_rast_b)
  terra::ifel(!is.na(ov[["depth_min_overlap"]]), 1, NA)
}
