#' Create a study area raster grid
#'
#' Build an empty raster covering the combined extent of one or more spatial
#' objects. Useful for defining the common grid before rasterizing species
#' ranges and fishery footprints.
#'
#' @param layers List of sf, sfc, SpatVector, or SpatRaster objects. The output
#'   extent will cover all objects.
#' @param res Numeric vector of length 1 or 2. Cell resolution in units of
#'   `crs` (degrees for lon/lat). Default `0.01` (~1 km at equator).
#' @param crs Character. Coordinate reference system. Default `"EPSG:4326"`.
#'
#' @returns An empty SpatRaster with the computed extent, resolution, and CRS.
#' @export
create_study_raster <- function(layers, res = 0.01, crs = "EPSG:4326") {
  extents <- lapply(layers, function(x) {
    if (inherits(x, "sf") || inherits(x, "sfc")) {
      x <- terra::vect(x)
    }
    if (inherits(x, "SpatVector")) {
      x <- terra::project(x, crs)
    } else if (inherits(x, "SpatRaster")) {
      x <- terra::project(x, crs)
    }
    terra::ext(x)
  })

  combined <- extents[[1]]
  for (i in seq_along(extents)[-1]) {
    combined <- terra::union(combined, extents[[i]])
  }

  terra::rast(combined, res = res, crs = crs)
}

#' Rasterize a species range or fishery footprint onto a study grid
#'
#' Rasterize polygons onto a study grid and assign depth limits per cell.
#' The maximum depth is clamped to the bathymetry (seafloor) so it never
#' exceeds the actual depth at each cell. Cells where the minimum depth is
#' deeper than the seafloor are set to NA (species not present).
#'
#' @param polygons sf or SpatVector. Species range or fishery footprint
#'   polygons.
#' @param grid SpatRaster. Study area raster grid (e.g., from
#'   [create_study_raster()]).
#' @param bathymetry SpatRaster. Seafloor depth raster with positive values
#'   in metres, matching the CRS and resolution of `grid`. Pre-prepare from
#'   GEBCO with: `seafloor <- terra::clamp(-terra::project(bathy, grid), lower = 0)`.
#' @param depth_min Numeric. Minimum (shallowest) depth in metres.
#' @param depth_max Numeric. Maximum (deepest) depth in metres.
#'
#' @returns Multi-layer SpatRaster with layers: depth_min, depth_max.
#'   Cells where the species/fishery is absent or the seafloor is shallower
#'   than depth_min are NA.
#' @export
rasterize_range <- function(polygons, grid, bathymetry, depth_min, depth_max) {
  if (!terra::same.crs(bathymetry, grid)) {
    stop("bathymetry CRS does not match grid. Pre-project bathymetry onto the study grid.")
  }
  if (!all(terra::res(bathymetry) == terra::res(grid))) {
    stop("bathymetry resolution does not match grid. Pre-project bathymetry onto the study grid.")
  }

  if (inherits(polygons, "sf") || inherits(polygons, "sfc")) {
    polygons <- terra::vect(polygons)
  }
  polygons <- terra::project(polygons, grid)

  # Rasterize presence onto the study grid
  presence <- terra::rasterize(polygons, grid, field = 1, background = NA)

  seafloor <- bathymetry

  # Mask seafloor to where the range is present
  seafloor <- terra::mask(seafloor, presence)

  # Remove cells where seafloor is shallower than depth_min
  # (species cannot be present if water is too shallow)
  valid <- terra::ifel(seafloor >= depth_min, 1, NA)

  # depth_min layer: constant where valid
  dmin_rast <- valid * depth_min
  names(dmin_rast) <- "depth_min"

  # depth_max layer: clamped to seafloor
  dmax_rast <- terra::ifel(seafloor < depth_max, seafloor, valid * depth_max)
  names(dmax_rast) <- "depth_max"

  c(dmin_rast, dmax_rast)
}

#' Rasterize multiple ranges onto a study grid
#'
#' Wrapper around [rasterize_range()] that processes multiple rows of an sf
#' object, each with its own depth limits. Displays a progress bar.
#'
#' @param sf_data sf object. Each row is a separate range to rasterize.
#' @param grid SpatRaster. Study area raster grid (e.g., from
#'   [create_study_raster()]).
#' @param bathymetry SpatRaster. Bathymetry raster with negative values for
#'   depth below sea level (e.g., from [load_bathymetry()]).
#' @param depth_min_col Character. Column name in `sf_data` containing the
#'   minimum (shallowest) depth in metres.
#' @param depth_max_col Character. Column name in `sf_data` containing the
#'   maximum (deepest) depth in metres.
#' @param name_col Character. Optional column name to use for naming the
#'   output list. Default `NULL` (unnamed).
#'
#' @returns Named list of multi-layer SpatRasters (output of
#'   [rasterize_range()]).
#' @export
rasterize_ranges <- function(sf_data, grid, bathymetry,
                             depth_min_col, depth_max_col,
                             name_col = NULL) {
  n <- nrow(sf_data)
  message("Rasterizing ", n, " ranges...")
  pb <- txtProgressBar(min = 0, max = n, style = 3)

  results <- lapply(seq_len(n), function(i) {
    row <- sf_data[i, ]
    result <- rasterize_range(
      polygons = row,
      grid = grid,
      bathymetry = bathymetry,
      depth_min = row[[depth_min_col]],
      depth_max = row[[depth_max_col]]
    )
    setTxtProgressBar(pb, i)
    result
  })
  close(pb)

  if (!is.null(name_col)) {
    names(results) <- sf_data[[name_col]]
  }

  results
}

#' Calculate total 3D volume of a rasterized range
#'
#' Volume = sum of (cell_area x (depth_max - depth_min)) across all present
#' cells.
#'
#' @param range_rast SpatRaster. Output from [rasterize_range()], with layers:
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

#' Binary 3D overlap between two rasterized ranges
#'
#' Returns a single-layer raster that is `1` in cells where the two ranges
#' overlap both horizontally (both present) and vertically (their depth
#' intervals intersect), and `NA` otherwise. Useful for richness / tally
#' maps where the per-cell overlap volume is not needed.
#'
#' @param range_rast_a SpatRaster. First rasterized range (output of
#'   [rasterize_range()]).
#' @param range_rast_b SpatRaster. Second rasterized range (output of
#'   [rasterize_range()]).
#'
#' @returns Single-layer SpatRaster (`1` where the two ranges overlap in 3D,
#'   `NA` elsewhere).
#' @export
count_3d_overlap <- function(range_rast_a, range_rast_b) {
  both_present <- !is.na(range_rast_a[["depth_min"]]) &
    !is.na(range_rast_b[["depth_min"]])

  dmin_a <- range_rast_a[["depth_min"]]
  dmax_a <- range_rast_a[["depth_max"]]
  dmin_b <- range_rast_b[["depth_min"]]
  dmax_b <- range_rast_b[["depth_max"]]

  overlap_min <- terra::ifel(dmin_a > dmin_b, dmin_a, dmin_b)
  overlap_max <- terra::ifel(dmax_a < dmax_b, dmax_a, dmax_b)

  has_overlap <- both_present & (overlap_max > overlap_min)
  terra::ifel(has_overlap, 1, NA)
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
#' @returns Multi-layer SpatRaster with layers: volume_a, volume_b,
#'   volume_overlap. Each layer contains per-cell volume in km³.
#' @export
calc_volume_overlap <- function(range_rast_a, range_rast_b) {
  cell_area_km2 <- terra::cellSize(range_rast_a[["depth_min"]], unit = "km")

  # Per-cell volume for A
  depth_a <- range_rast_a[["depth_max"]] - range_rast_a[["depth_min"]]
  vol_a <- cell_area_km2 * (depth_a / 1000)
  names(vol_a) <- "volume_a"

  # Per-cell volume for B
  depth_b <- range_rast_b[["depth_max"]] - range_rast_b[["depth_min"]]
  vol_b <- cell_area_km2 * (depth_b / 1000)
  names(vol_b) <- "volume_b"

  # Mask to cells where both ranges are present
  both_present <- !is.na(range_rast_a[["depth_min"]]) & !is.na(range_rast_b[["depth_min"]])
  both_present <- terra::ifel(both_present, 1, NA)

  dmin_a <- terra::mask(range_rast_a[["depth_min"]], both_present)
  dmax_a <- terra::mask(range_rast_a[["depth_max"]], both_present)
  dmin_b <- terra::mask(range_rast_b[["depth_min"]], both_present)
  dmax_b <- terra::mask(range_rast_b[["depth_max"]], both_present)

  # Per-cell depth overlap: overlap of two depth intervals
  overlap_min <- terra::ifel(dmin_a > dmin_b, dmin_a, dmin_b)
  overlap_max <- terra::ifel(dmax_a < dmax_b, dmax_a, dmax_b)
  overlap_depth <- overlap_max - overlap_min
  overlap_depth <- terra::clamp(overlap_depth, lower = 0)
  vol_overlap <- cell_area_km2 * (overlap_depth / 1000)
  names(vol_overlap) <- "volume_overlap"

  c(vol_a, vol_b, vol_overlap)
}
