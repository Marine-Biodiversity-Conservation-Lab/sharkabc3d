# Constructors 

#' Create envelope object
#' @noRd
as_envelope <- function(x, depth_min, depth_max, seafloor = NULL) {
  stop("not implemented yet")
}

#' Create voxel object
#' @noRd
as_voxel <- function(x) {
  # Convert multi-depth SpatRaster into VoxelRaster, ex. WOA data
  if(FALSE) {

  }

  stop("not implemented yet")
}

#' Convert Envelope 2.5D -> Voxel 3D
#' @noRd
envelope_to_voxel <- function(x, depths, values = NULL, varname = "presence") {
  stop("not implemented yet")
}

#' Collapse Voxel 3D -> Envelope 2.5D
#'
#' Reduce a [SpatVoxel-class] to the [SpatEnvelope-class] that bounds it. A
#' predicate `fun` is applied to the cell values at each depth; for every cell,
#' the shallowest depth at which the predicate is `TRUE` becomes `depth_min`
#' and the deepest becomes `depth_max`. Cells where the predicate is never
#' `TRUE` are `NA` in both layers.
#'
#' The default predicate, `\(x) !is.na(x)`, gives the plain vertical extent of
#' the data: the shallowest and deepest depths at which the cell has any value.
#' Pass a different predicate to bound a subset of the values instead, e.g.
#' `\(x) x > 15` for the depths over which a cell exceeds 15 degrees.
#'
#' **This conversion is lossy.** An envelope stores a single continuous
#' interval per cell, so any interior gap in the voxel is filled in: a cell that
#' satisfies `fun` at 0 m and 200 m but not at 100 m still yields the envelope
#' `[0, 200]`. Use [SpatVoxel-class] directly where interior gaps matter.
#'
#' @param v SpatVoxel (or a multi-depth SpatRaster with
#'   `{variable}_depth={value}` layer names).
#' @param fun Function taking a vector of cell values and returning a logical
#'   vector of the same length. `NA` results are treated as `FALSE`. Defaults to
#'   `\(x) !is.na(x)`.
#'
#' @returns A [SpatEnvelope-class] with layers `depth_min` and `depth_max`, on
#'   the same grid as `v`.
#' @export
voxel_to_envelope <- function(v, fun = function(x) !is.na(x)) {
  if (!is.function(fun)) {
    stop("`fun` must be a function returning TRUE/FALSE for a cell value. ",
         "The former \"extent\" behaviour is the default, function(x) !is.na(x).",
         call. = FALSE)
  }

  depths <- .parse_depth_layers(v)

  # Depth stamp per layer: the layer's depth where `fun` holds, NA elsewhere.
  # `fun` is evaluated on the values rather than on the SpatRaster so that any
  # ordinary R predicate works, not only terra-aware ones.
  stamped <- lapply(seq_along(depths), function(i) {
    hit <- as.logical(fun(terra::values(v[[i]], mat = FALSE)))
    if (length(hit) != terra::ncell(v)) {
      stop("`fun` must return one TRUE/FALSE per cell value; got ",
           length(hit), " values for ", terra::ncell(v), " cells.",
           call. = FALSE)
    }
    hit[is.na(hit)] <- FALSE
    terra::setValues(terra::rast(v[[i]]),
                     ifelse(hit, depths[i], NA_real_))
  })

  stamped <- terra::rast(stamped)
  # all-NA cells (predicate never TRUE) must stay NA, not become +/-Inf
  any_hit <- terra::app(stamped, function(x) as.numeric(any(!is.na(x))))
  any_hit <- terra::ifel(any_hit > 0, 1, NA)

  out <- c(
    terra::mask(min(stamped, na.rm = TRUE), any_hit),
    terra::mask(max(stamped, na.rm = TRUE), any_hit)
  )
  names(out) <- c("depth_min", "depth_max")

  out <- methods::new("SpatEnvelope", out)
  methods::validObject(out)
  out
}
