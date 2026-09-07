# R/AllGenerics.R
#
# Generics for the operations that are meaningful on either 3D representation.
# The methods live in R/volume.R; only the dispatch contract is declared here.

#' @importFrom methods setGeneric setMethod
NULL

#' Total 3D volume of a rasterized domain
#'
#' Sums the occupied volume of a [SpatEnvelope-class] or a [SpatVoxel-class]
#' over the whole grid. Both representations describe a 3D domain over a 2D
#' grid, but they store depth in dual roles, so each computes the vertical
#' extent differently:
#'
#' \describe{
#'   \item{[SpatEnvelope-class]}{Depth is the cell value, and the interval is
#'     solid by construction. Volume is
#'     `sum(cell_area * (depth_max - depth_min))` over present cells.}
#'   \item{[SpatVoxel-class]}{Depth is the layer index. Each occupied voxel
#'     contributes its cell area times the thickness of the slab its depth
#'     level stands for, so interior gaps are excluded rather than filled.}
#' }
#'
#' A voxel volume is quantized to the levels the voxel was sampled at, and a
#' voxel built by [envelope_to_voxel()] counts a level as occupied on *any*
#' overlap with the envelope. So a range of 0-100 m discretized onto
#' 0, 50, 100, 150, 200 m occupies three levels spanning 0-150 m and reports
#' more water than the envelope it came from. Coarse levels overstate; the
#' error shrinks as the levels tighten around the range. Where an envelope's
#' limits fall exactly on levels under `bounds = "top"`, the two agree.
#'
#' @param x A [SpatEnvelope-class] or [SpatVoxel-class]. A bare SpatRaster is
#'   rejected; build one with [as_envelope()], [vect_to_envelope()] or
#'   [as_voxel()] first.
#' @param ... Arguments for the [SpatVoxel-class] method, which are an error
#'   for an envelope.
#' @param bounds SpatVoxel only. What each depth level stands for vertically:
#'   `"top"` (default) treats the level as the top of its slab, so the slab
#'   runs down to the next level; `"midpoint"` puts the level in the middle,
#'   with edges halfway to each neighbour (the World Ocean Atlas convention).
#'   Under `"top"` the deepest level has no next level and contributes no
#'   volume. Outer edges are clamped to `range(depths)` under both. Same
#'   argument, same meaning, as in [envelope_to_voxel()].
#' @param fun SpatVoxel only. Predicate deciding whether a voxel is occupied,
#'   applied one depth layer at a time. Defaults to `function(v) !is.na(v)`,
#'   the same default [voxel_to_envelope()] uses. `NA` results count as
#'   unoccupied.
#'
#' @returns Numeric of length 1. Total volume in km³.
#'
#' @seealso [calc_volume_overlap()] for the volume two domains share;
#'   [SpatVolume-class] for why the two representations dispatch separately.
#'
#' @examples
#' fp <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2000,
#'                   ymin = 0, ymax = 2000,
#'                   crs = "+proj=laea +lat_0=0 +lon_0=0 +datum=WGS84 +units=m")
#' terra::values(fp) <- c(1, 1, 1, NA)
#'
#' # 2.5D: three 1 km² cells, each 0-200 m => 3 * 1 * 0.2 = 0.6 km³.
#' e <- as_envelope(fp, depth_min = 0, depth_max = 200)
#' volume(e)
#'
#' # 3D: the same domain on three levels. Under "top" the slabs are 100 m,
#' # 100 m and 0 m, so the discretized volume matches exactly here.
#' v <- envelope_to_voxel(e, depths = c(0, 100, 200))
#' volume(v)
#'
#' # An interior gap is volume a voxel can drop and an envelope cannot.
#' gappy <- v
#' gappy[[2]] <- terra::setValues(terra::rast(v[[2]]), NA)
#' gappy <- as_voxel(gappy)
#' volume(gappy)
#' volume(voxel_to_envelope(gappy))
#' @export
setGeneric("volume", function(x, ...) standardGeneric("volume"))

#' Per-cell 3D volume overlap between two rasterized domains
#'
#' Computes the depth interval and volume of each domain and of their
#' intersection, cell by cell. Accepts any combination of
#' [SpatEnvelope-class] and [SpatVoxel-class]; when the two differ, the
#' envelope is discretized onto the voxel's depth levels with
#' [envelope_to_voxel()] rather than the voxel being collapsed, because
#' [voxel_to_envelope()] fills interior gaps and would overstate the overlap.
#'
#' Two voxels must be sampled at the same depth levels, and all inputs must be
#' on the same grid.
#'
#' @param x,y The two domains, each a [SpatEnvelope-class] or
#'   [SpatVoxel-class].
#' @param ... Arguments for the voxel methods, which are an error for a pair
#'   of envelopes.
#' @param bounds Voxel methods only. See [volume()]. Also governs how an
#'   envelope is discretized when the two inputs differ.
#' @param fun Voxel methods only. See [volume()].
#'
#' @returns Multi-layer SpatRaster with 9 layers:
#'   \describe{
#'     \item{depth_min_a, depth_max_a}{Depth limits of `x` (m)}
#'     \item{depth_min_b, depth_max_b}{Depth limits of `y` (m)}
#'     \item{depth_min_overlap, depth_max_overlap}{Depth limits of the
#'       intersection (m). NA where the domains do not overlap in depth.}
#'     \item{volume_a, volume_b}{Per-cell volume of each domain (km³)}
#'     \item{volume_overlap}{Per-cell overlap volume (km³). `0` where both are
#'       present but their depths do not intersect, NA where either is
#'       absent.}
#'   }
#'
#'   For voxel inputs the depth layers are *summary bounds* — the shallowest
#'   and deepest occupied level. A voxel with an interior gap is not solid
#'   between them, so read the volume layers, not the depth layers, for
#'   occupied volume. The result is a plain SpatRaster: it is neither an
#'   envelope nor a voxel.
#'
#' @seealso [count_3d_overlap()] when only the presence of overlap is needed.
#'
#' @examples
#' fp <- terra::rast(nrows = 1, ncols = 2, xmin = 0, xmax = 2000,
#'                   ymin = 0, ymax = 1000,
#'                   crs = "+proj=laea +lat_0=0 +lon_0=0 +datum=WGS84 +units=m")
#' terra::values(fp) <- c(1, 1)
#'
#' a <- as_envelope(fp, depth_min = 0, depth_max = 100)
#' b <- as_envelope(fp, depth_min = 50, depth_max = 200)
#'
#' ov <- calc_volume_overlap(a, b)
#' names(ov)
#' terra::global(ov[[c("volume_a", "volume_b", "volume_overlap")]], "sum",
#'               na.rm = TRUE)
#'
#' # Mixed input: the envelope is discretized onto the voxel's levels.
#' bv <- envelope_to_voxel(b, depths = c(0, 50, 100, 150, 200))
#' terra::global(calc_volume_overlap(a, bv)[["volume_overlap"]], "sum",
#'               na.rm = TRUE)
#' @export
setGeneric("calc_volume_overlap",
           function(x, y, ...) standardGeneric("calc_volume_overlap"))

#' Binary 3D overlap between two rasterized domains
#'
#' Returns a single-layer raster that is `1` in cells where the two domains
#' overlap both horizontally (both present) and vertically (their depths
#' intersect), and `NA` otherwise. Use it for richness and tally maps, where
#' the per-cell overlap volume is not needed: unlike [calc_volume_overlap()]
#' it computes only the presence pattern, with no cell areas and no volumes.
#'
#' Mixed input is resolved the same way as in [calc_volume_overlap()] — the
#' envelope is discretized onto the voxel's depth levels.
#'
#' @param x,y The two domains, each a [SpatEnvelope-class] or
#'   [SpatVoxel-class].
#' @param ... Arguments for the voxel methods, which are an error for a pair
#'   of envelopes.
#' @param bounds Used only where an envelope must be discretized onto a
#'   voxel's levels. See [volume()].
#' @param fun Voxel methods only. See [volume()].
#'
#' @returns Single-layer SpatRaster named `overlap`, `1` where the two domains
#'   overlap in 3D and `NA` elsewhere.
#'
#' @seealso [calc_volume_overlap()] for the overlap volume itself.
#'
#' @examples
#' fp <- terra::rast(nrows = 1, ncols = 3, xmin = 0, xmax = 3000,
#'                   ymin = 0, ymax = 1000,
#'                   crs = "+proj=laea +lat_0=0 +lon_0=0 +datum=WGS84 +units=m")
#' terra::values(fp) <- c(1, 1, NA)
#'
#' a <- as_envelope(fp, depth_min = 0, depth_max = 100)
#' b <- as_envelope(
#'   fp, depth_min = 0,
#'   depth_max = terra::setValues(terra::rast(fp), c(50, NA, 300))
#' )
#'
#' # Cell 1 overlaps; cell 2 has no B; cell 3 has no A.
#' terra::values(count_3d_overlap(a, b))
#'
#' # Summing a stack of these gives a richness map.
#' terra::global(count_3d_overlap(a, b), "sum", na.rm = TRUE)
#' @export
setGeneric("count_3d_overlap",
           function(x, y, ...) standardGeneric("count_3d_overlap"))
