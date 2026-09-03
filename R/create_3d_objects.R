# Constructors 

#' Create envelope object
#' @noRd
as_envelope <- function(x, depth_min, depth_max, seafloor = NULL) {
  stop("not implemented yet")
}

#' Create a voxel object
#'
#' Wrap a multi-depth raster as a [SpatVoxel-class]: the validated 3D form used
#' throughout the package, with one layer per standard depth and layer names
#' following the `{variable}_depth={value}` convention.
#'
#' Most terra operations (`crop()`, `mask()`, `[[`) return a plain `SpatRaster`
#' and so drop the class, which makes re-wrapping a routine step. `as_voxel()`
#' is idempotent for that reason — given a `SpatVoxel` it returns it untouched.
#'
#' Depths are positive metres increasing downward, matching the World Ocean
#' Atlas convention. Negative depths are an error rather than being silently
#' negated, since flipping the sign would change what the data mean.
#'
#' @param x SpatRaster with `{variable}_depth={value}` layer names, a list of
#'   single-depth SpatRasters, or an existing [SpatVoxel-class].
#' @param depths Optional numeric vector, one depth per layer, in metres. When
#'   supplied, layer names are (re)built from `depths` and `varname`, replacing
#'   any existing names. Required if `x` has no conforming layer names.
#' @param varname Character. Variable name used when building layer names from
#'   `depths`. Ignored when `depths` is `NULL`.
#'
#' @returns A [SpatVoxel-class] whose layers are ordered shallow to deep.
#' @examples
#' r <- terra::rast(nrows = 2, ncols = 2, nlyrs = 3)
#' terra::values(r) <- runif(terra::ncell(r) * 3)
#'
#' # build the layer names from a depth vector
#' v <- as_voxel(r, depths = c(0, 100, 200), varname = "temp")
#' names(v)
#'
#' # already-conforming names are used as they stand, and sorted if needed
#' names(r) <- c("temp_depth=200", "temp_depth=0", "temp_depth=100")
#' names(as_voxel(r))
#' @export
as_voxel <- function(x, depths = NULL, varname = "value") {
  # Idempotent: re-wrapping is routine, because terra operations drop the class
  if (methods::is(x, "SpatVoxel") && is.null(depths)) return(x)

  if (is.list(x)) x <- terra::rast(x)
  if (!methods::is(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster or a list of SpatRasters; got ",
         paste(class(x), collapse = "/"), ".", call. = FALSE)
  }

  if (!is.null(depths)) {
    if (length(depths) != terra::nlyr(x)) {
      stop("`depths` must have one value per layer: got ", length(depths),
           " for ", terra::nlyr(x), " layers.", call. = FALSE)
    }
    if (!is.numeric(depths)) {
      stop("`depths` must be numeric metres.", call. = FALSE)
    }
    names(x) <- paste0(varname, "_depth=", depths)
  }

  d <- .parse_depth_layers(x, error = FALSE)
  if (anyNA(d)) {
    stop("layer(s) ", paste(names(x)[is.na(d)], collapse = ", "),
         " do not follow the '{variable}_depth={value}' convention. ",
         "Pass `depths` to build the layer names instead.", call. = FALSE)
  }
  if (any(d < 0)) {
    stop("depths are positive metres increasing downward; got ",
         paste(d[d < 0], collapse = ", "),
         ". Negate the depths in the layer names or in `depths`.",
         call. = FALSE)
  }
  if (anyDuplicated(d)) {
    stop("duplicate depth(s): ", paste(unique(d[duplicated(d)]), collapse = ", "),
         ". Each layer must be a distinct depth.", call. = FALSE)
  }

  # Repair what is unambiguously repairable rather than rejecting it.
  if (is.unsorted(d)) x <- x[[order(d)]]

  methods::new("SpatVoxel", x)
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
  if (!is(v, "SpatVoxel")) {
    stop("`v` must be a SpatVoxel object.")
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
