# R/volume.R
#
# Volume and volumetric overlap for the package's two 3D representations. The
# generics are declared in R/AllGenerics.R; this file holds the arithmetic.
#
# SpatEnvelope and SpatVoxel both describe a 3D domain over a 2D grid, but they
# store depth in dual roles -- the envelope as a per-cell value, the voxel as
# the layer index -- so the vertical extent is derived differently in each and
# each gets its own method rather than a shared SpatVolume one. See
# [SpatVolume-class].
#
# The internals both this file and R/intersect.R rely on (occupancy, presence,
# cell areas, grid and depth checks) live in R/utils-3d.R.

# ---- volume ------------------------------------------------------------

#' @rdname volume
#' @export
setMethod("volume", "SpatEnvelope", function(x, ...) {
  .no_extra_args(...)

  depth_extent <- x[["depth_max"]] - x[["depth_min"]]

  # Volume per cell in km³ (depth in m, converted to km)
  vol_rast <- .cell_area_km2(x) * (depth_extent / 1000)

  terra::global(vol_rast, "sum", na.rm = TRUE)[[1]]
})

#' @rdname volume
#' @export
setMethod(
  "volume", "SpatVoxel",
  function(x, bounds = c("top", "midpoint"), fun = function(v) !is.na(v)) {
    bounds <- match.arg(bounds)

    depths <- .parse_depth_layers(x)
    occ <- .voxel_occupancy(x, fun)
    vol_rast <- .voxel_cell_volume(occ, depths, bounds, .cell_area_km2(x))

    terra::global(vol_rast, "sum", na.rm = TRUE)[[1]]
  }
)

# Rejected here rather than by S4's default "unable to find an inherited
# method", which says nothing about how to build the right object.
#' @rdname volume
#' @export
setMethod("volume", "SpatRaster", function(x, ...) .stop_not_volume())

# ---- calc_volume_overlap ----------------------------------------------------

#' @rdname calc_volume_overlap
#' @export
setMethod(
  "calc_volume_overlap", c("SpatEnvelope", "SpatEnvelope"),
  function(x, y, ...) {
    .no_extra_args(...)
    .check_same_grid(x, y)

    cell_area_km2 <- .cell_area_km2(x)

    # Depth layers for A
    dmin_a <- x[["depth_min"]]
    dmax_a <- x[["depth_max"]]
    names(dmin_a) <- "depth_min_a"
    names(dmax_a) <- "depth_max_a"

    # Depth layers for B
    dmin_b <- y[["depth_min"]]
    dmax_b <- y[["depth_max"]]
    names(dmin_b) <- "depth_min_b"
    names(dmax_b) <- "depth_max_b"

    # Per-cell volume for A and B
    vol_a <- cell_area_km2 * ((dmax_a - dmin_a) / 1000)
    names(vol_a) <- "volume_a"
    vol_b <- cell_area_km2 * ((dmax_b - dmin_b) / 1000)
    names(vol_b) <- "volume_b"

    # Intersection depth interval (only where both present)
    both_present <- !is.na(dmin_a) & !is.na(dmax_a) &
      !is.na(dmin_b) & !is.na(dmax_b)
    both_mask <- terra::ifel(both_present, 1, NA)

    overlap_min <- terra::mask(terra::ifel(dmin_a > dmin_b, dmin_a, dmin_b),
                               both_mask)
    overlap_max <- terra::mask(terra::ifel(dmax_a < dmax_b, dmax_a, dmax_b),
                               both_mask)

    # Set to NA where depth intervals do not overlap. Strict `>`: intervals
    # that merely touch share no volume.
    has_overlap <- terra::ifel(overlap_max > overlap_min, 1, NA)
    overlap_min <- terra::mask(overlap_min, has_overlap)
    overlap_max <- terra::mask(overlap_max, has_overlap)
    names(overlap_min) <- "depth_min_overlap"
    names(overlap_max) <- "depth_max_overlap"

    # Masking by has_overlap already leaves the difference positive or NA, so
    # the fill below is what distinguishes the two ways a cell can have no
    # overlap: 0 where both are present but vertically disjoint, NA where one
    # is absent.
    overlap_depth <- overlap_max - overlap_min
    overlap_depth <- terra::mask(overlap_depth, both_mask)
    overlap_depth <- terra::ifel(is.na(overlap_depth) & both_present, 0,
                                 overlap_depth)
    vol_overlap <- cell_area_km2 * (overlap_depth / 1000)
    names(vol_overlap) <- "volume_overlap"

    c(dmin_a, dmax_a, dmin_b, dmax_b, overlap_min, overlap_max,
      vol_a, vol_b, vol_overlap)
  }
)

#' @rdname calc_volume_overlap
#' @export
setMethod(
  "calc_volume_overlap", c("SpatVoxel", "SpatVoxel"),
  function(x, y, bounds = c("top", "midpoint"), fun = function(v) !is.na(v)) {
    bounds <- match.arg(bounds)
    .check_same_grid(x, y)
    depths <- .shared_depths(x, y)

    occ_a <- .voxel_occupancy(x, fun)
    occ_b <- .voxel_occupancy(y, fun)
    occ_overlap <- occ_a * occ_b
    names(occ_overlap) <- names(occ_a)

    cell_area_km2 <- .cell_area_km2(x)

    present_a <- .voxel_present(occ_a)
    present_b <- .voxel_present(occ_b)
    both_mask <- terra::mask(present_a, present_b)

    # Summary depth bounds, not a claim that the domain is solid between them.
    bounds_a <- .occupancy_bounds(occ_a)
    bounds_b <- .occupancy_bounds(occ_b)
    bounds_overlap <- .occupancy_bounds(occ_overlap)

    dmin_a <- bounds_a[["depth_min"]]
    dmax_a <- bounds_a[["depth_max"]]
    names(dmin_a) <- "depth_min_a"
    names(dmax_a) <- "depth_max_a"

    dmin_b <- bounds_b[["depth_min"]]
    dmax_b <- bounds_b[["depth_max"]]
    names(dmin_b) <- "depth_min_b"
    names(dmax_b) <- "depth_max_b"

    overlap_min <- bounds_overlap[["depth_min"]]
    overlap_max <- bounds_overlap[["depth_max"]]
    names(overlap_min) <- "depth_min_overlap"
    names(overlap_max) <- "depth_max_overlap"

    # Volumes come from the occupancy stacks, so interior gaps are excluded
    # even though the depth bounds above span them.
    vol_a <- terra::mask(
      .voxel_cell_volume(occ_a, depths, bounds, cell_area_km2), present_a)
    names(vol_a) <- "volume_a"
    vol_b <- terra::mask(
      .voxel_cell_volume(occ_b, depths, bounds, cell_area_km2), present_b)
    names(vol_b) <- "volume_b"

    # Already 0 where both are present but share no occupied level; masking to
    # both_mask makes it NA where either is absent, matching the 2.5D method.
    vol_overlap <- terra::mask(
      .voxel_cell_volume(occ_overlap, depths, bounds, cell_area_km2),
      both_mask)
    names(vol_overlap) <- "volume_overlap"

    c(dmin_a, dmax_a, dmin_b, dmax_b, overlap_min, overlap_max,
      vol_a, vol_b, vol_overlap)
  }
)

#' @rdname calc_volume_overlap
#' @export
setMethod(
  "calc_volume_overlap", c("SpatEnvelope", "SpatVoxel"),
  function(x, y, bounds = c("top", "midpoint"), ...) {
    bounds <- match.arg(bounds)
    calc_volume_overlap(.promote_to_voxel(x, y, bounds), y,
                        bounds = bounds, ...)
  }
)

#' @rdname calc_volume_overlap
#' @export
setMethod(
  "calc_volume_overlap", c("SpatVoxel", "SpatEnvelope"),
  function(x, y, bounds = c("top", "midpoint"), ...) {
    bounds <- match.arg(bounds)
    calc_volume_overlap(x, .promote_to_voxel(y, x, bounds),
                        bounds = bounds, ...)
  }
)

#' @rdname calc_volume_overlap
#' @export
setMethod("calc_volume_overlap", c("SpatRaster", "SpatRaster"),
          function(x, y, ...) .stop_not_volume())
#' @rdname calc_volume_overlap
#' @export
setMethod("calc_volume_overlap", c("SpatRaster", "SpatVolume"),
          function(x, y, ...) .stop_not_volume())
#' @rdname calc_volume_overlap
#' @export
setMethod("calc_volume_overlap", c("SpatVolume", "SpatRaster"),
          function(x, y, ...) .stop_not_volume())

# ---- count_3d_overlap -------------------------------------------------------

#' @rdname count_3d_overlap
#' @export
setMethod(
  "count_3d_overlap", c("SpatEnvelope", "SpatEnvelope"),
  function(x, y, ...) {
    .no_extra_args(...)
    .check_same_grid(x, y)

    # Only the presence pattern is wanted, so no cell areas and no volumes.
    # Where either domain is absent the comparison is NA and falls through to
    # NA, which is the answer.
    overlap_min <- terra::ifel(x[["depth_min"]] > y[["depth_min"]],
                               x[["depth_min"]], y[["depth_min"]])
    overlap_max <- terra::ifel(x[["depth_max"]] < y[["depth_max"]],
                               x[["depth_max"]], y[["depth_max"]])

    out <- terra::ifel(overlap_max > overlap_min, 1, NA)
    names(out) <- "overlap"
    out
  }
)

#' @rdname count_3d_overlap
#' @export
setMethod(
  "count_3d_overlap", c("SpatVoxel", "SpatVoxel"),
  function(x, y, fun = function(v) !is.na(v)) {
    .check_same_grid(x, y)
    .shared_depths(x, y)

    occ_overlap <- .voxel_occupancy(x, fun) * .voxel_occupancy(y, fun)

    out <- terra::ifel(sum(occ_overlap) > 0, 1, NA)
    names(out) <- "overlap"
    out
  }
)

#' @rdname count_3d_overlap
#' @export
setMethod(
  "count_3d_overlap", c("SpatEnvelope", "SpatVoxel"),
  function(x, y, bounds = c("top", "midpoint"), ...) {
    bounds <- match.arg(bounds)
    count_3d_overlap(.promote_to_voxel(x, y, bounds), y, ...)
  }
)

#' @rdname count_3d_overlap
#' @export
setMethod(
  "count_3d_overlap", c("SpatVoxel", "SpatEnvelope"),
  function(x, y, bounds = c("top", "midpoint"), ...) {
    bounds <- match.arg(bounds)
    count_3d_overlap(x, .promote_to_voxel(y, x, bounds), ...)
  }
)

#' @rdname count_3d_overlap
#' @export
setMethod("count_3d_overlap", c("SpatRaster", "SpatRaster"),
          function(x, y, ...) .stop_not_volume())
#' @rdname count_3d_overlap
#' @export
setMethod("count_3d_overlap", c("SpatRaster", "SpatVolume"),
          function(x, y, ...) .stop_not_volume())
#' @rdname count_3d_overlap
#' @export
setMethod("count_3d_overlap", c("SpatVolume", "SpatRaster"),
          function(x, y, ...) .stop_not_volume())
