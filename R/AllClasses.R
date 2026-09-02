# R/AllClasses.R

#' @importFrom methods setClass setClassUnion setValidity new validObject
#' @importClassesFrom terra SpatRaster
NULL

#' 3D voxel model: one layer per standard depth level
#'
#' A `SpatVoxel` is a [terra::SpatRaster] in which **depth is the layer index**
#' and the cell values are the variable (temperature, oxygen, presence, ...).
#' Layer names follow the `{variable}_depth={value}` convention and must be
#' ordered shallow to deep. The depth axis is grid-wide: every cell is sampled
#' at the same set of standard depths.
#'
#' A voxel may have interior gaps — a cell can be NA at one depth and non-NA
#' at the depths above and below it.
#'
#' @seealso [SpatEnvelope-class], [SpatVolume-class]
#' @export
setClass("SpatVoxel", contains = "SpatRaster")

#' 2.5D min-max envelope: exactly depth_min, depth_max
#'
#' A `SpatEnvelope` is a [terra::SpatRaster] with exactly two layers,
#' `depth_min` and `depth_max`, in which **depth is the cell value**. The
#' variable is the object itself: the envelope delimits the vertical extent of
#' a spatial phenomenon (typically a species range) rather than sampling a
#' variable within it.
#'
#' The vertical interval is per-cell and continuous, and is solid by
#' construction — an envelope cannot represent a gap in the vertical
#' distribution.
#'
#' @seealso [SpatVoxel-class], [SpatVolume-class]
#' @export
setClass("SpatEnvelope", contains = "SpatRaster")

#' Union of the package's 3D domain representations
#'
#' `SpatVolume` is a class union over [SpatVoxel-class] and
#' [SpatEnvelope-class]. It exists as a dispatch target for operations that are
#' meaningful on either representation because both determine a **3D domain
#' over a 2D grid**: volume, volumetric overlap, vertical extent, printing.
#'
#' It deliberately asserts no shared structure. The two members store depth in
#' dual roles (layer index vs. cell value), so any operation that touches the
#' depth axis directly should dispatch on the concrete class instead.
#'
#' @export
setClassUnion("SpatVolume", c("SpatVoxel", "SpatEnvelope"))

setValidity("SpatVoxel", function(object) {
  d <- .parse_depth_layers(object, error = FALSE)
  if (anyNA(d)) return("every layer name must follow {variable}_depth={value}")
  if (is.unsorted(d)) return("depth layers must be ordered shallow to deep")
  if (any(d < 0)) return("depths are positive metres increasing downward")
  TRUE
})

setValidity("SpatEnvelope", function(object) {
  if (!identical(names(object), c("depth_min", "depth_max")))
    return("layers must be exactly: depth_min, depth_max")
  TRUE
})
