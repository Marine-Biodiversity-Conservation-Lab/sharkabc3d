# Constructors 

#' Coerce a 2D footprint to a 2.5D min-max envelope
#'
#' Build a [SpatEnvelope-class] — one continuous `[depth_min, depth_max]`
#' interval per grid cell — from a 2D horizontal footprint and the depth limits
#' that apply to it. This is the general form of the conversion
#' [voxelize_range()] performs for polygons: any 2D raster whose non-`NA` cells
#' mark presence becomes a 3D domain once depth limits are attached to it.
#'
#' `x` is the footprint. Its values are not read, only their non-`NA` pattern:
#' a rasterized species range, a Global Fishing Watch effort layer, or a plain
#' presence mask all work. A SpatRaster that *already* has exactly the two
#' layers `depth_min` and `depth_max` (the output of [voxelize_range()], or a
#' [SpatEnvelope-class] itself) is promoted directly instead, in which case
#' `depth_min` and `depth_max` must be omitted.
#'
#' Depths are positive metres increasing downward, following the package's
#' depth sign convention. Pass GEBCO-style elevation through
#' [create_study_voxel()] first, which flips the sign and clamps land to 0.
#'
#' @param x SpatRaster. Either a single-layer footprint whose non-`NA` cells are
#'   present, or a two-layer raster already named `depth_min`, `depth_max`.
#' @param depth_min,depth_max Shallowest and deepest depth in metres, positive
#'   down. Each is either a single number applying to the whole footprint, or a
#'   single-layer SpatRaster on the grid of `x` giving the limit per cell. Omit
#'   both when `x` already carries the two depth layers.
#' @param seafloor SpatRaster or `NULL`. Optional single layer of positive-down
#'   seafloor depth (metres) on the grid of `x`, e.g. the `seafloor` element of
#'   a [create_study_voxel()] object. When supplied, `depth_max` is clamped to
#'   it so the envelope never reaches below the seabed, and cells whose seafloor
#'   is shallower than `depth_min` become `NA` — there is no water column left
#'   for the phenomenon to occupy.
#'
#' @returns A [SpatEnvelope-class] with layers `depth_min` and `depth_max`, on
#'   the grid of `x`.
#'
#' @seealso [voxel_to_envelope()] to collapse a [SpatVoxel-class] instead,
#'   [voxelize_range()] to go straight from polygons to an envelope, and
#'   [calc_volume()] to measure the result.
#'
#' @examples
#' # A 2x2 footprint: three cells present (any non-NA value), one absent.
#' fp <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
#' terra::values(fp) <- c(1, 1, 1, NA)
#'
#' # A species recorded between 0 and 200 m.
#' e <- as_envelope(fp, depth_min = 0, depth_max = 200)
#' terra::values(e)
#'
#' # Clamped to the seafloor: the third cell's seabed is at 50 m, so the
#' # envelope stops there rather than at the species' 200 m limit.
#' seabed <- terra::setValues(terra::rast(fp), c(500, 500, 50, 500))
#' terra::values(as_envelope(fp, 0, 200, seafloor = seabed))
#'
#' # Per-cell limits are allowed too, as single-layer rasters.
#' dmax <- terra::setValues(terra::rast(fp), c(100, 200, 300, 400))
#' terra::values(as_envelope(fp, depth_min = 10, depth_max = dmax))
#' @export
as_envelope <- function(x, depth_min, depth_max, seafloor = NULL) {
  if (inherits(x, "sf") || inherits(x, "sfc") || inherits(x, "SpatVector")) {
    stop("`x` must be a SpatRaster footprint, not vector geometry. ",
         "Rasterize the polygons onto the study grid first, or use ",
         "voxelize_range(), which does both.", call. = FALSE)
  }
  if (!inherits(x, "SpatRaster")) {
    stop("`x` must be a SpatRaster.", call. = FALSE)
  }

  # A raster already carrying the two depth layers is promoted, not rebuilt.
  already_envelope <- identical(names(x), c("depth_min", "depth_max"))
  supplied <- !missing(depth_min) || !missing(depth_max)

  if (already_envelope) {
    if (supplied) {
      stop("`x` already has depth_min and depth_max layers; omit the ",
           "`depth_min` and `depth_max` arguments.", call. = FALSE)
    }
    dmin <- x[["depth_min"]]
    dmax <- x[["depth_max"]]
  } else {
    if (missing(depth_min) || missing(depth_max)) {
      stop("`depth_min` and `depth_max` are required unless `x` already has ",
           "layers named depth_min and depth_max. Got layers: ",
           paste(names(x), collapse = ", "), call. = FALSE)
    }
    if (terra::nlyr(x) != 1) {
      stop("`x` must be a single-layer footprint when depth limits are ",
           "supplied; got ", terra::nlyr(x), " layers.", call. = FALSE)
    }

    # Only the non-NA pattern of the footprint matters, never its values.
    present <- terra::ifel(is.na(x), NA, 1)
    dmin <- terra::mask(.as_depth_layer(depth_min, "depth_min", x), present)
    dmax <- terra::mask(.as_depth_layer(depth_max, "depth_max", x), present)
  }

  # Checked before any seafloor clamp, so the error reports what was asked for.
  min_of <- function(r) {
    v <- terra::global(r, "min", na.rm = TRUE)[1, 1]
    if (is.null(v) || is.na(v)) NA_real_ else v
  }
  shallowest <- min_of(dmin)
  if (!is.na(shallowest) && shallowest < 0) {
    stop("depths are positive metres increasing downward; `depth_min` has ",
         "negative values. Flip the sign of elevation data first.",
         call. = FALSE)
  }
  thinnest <- min_of(dmax - dmin)
  if (!is.na(thinnest) && thinnest < 0) {
    stop("`depth_max` must be at least `depth_min` in every cell.",
         call. = FALSE)
  }

  if (!is.null(seafloor)) {
    if (!inherits(seafloor, "SpatRaster") || terra::nlyr(seafloor) != 1) {
      stop("`seafloor` must be a single-layer SpatRaster of positive-down ",
           "seafloor depth.", call. = FALSE)
    }
    if (!terra::compareGeom(seafloor, dmin, stopOnError = FALSE)) {
      stop("`seafloor` must be on the same grid (CRS, extent, resolution) ",
           "as `x`.", call. = FALSE)
    }
    # Where the seabed sits above the shallowest limit there is no water column
    # left, so the cell is absent; elsewhere the envelope stops at the seabed.
    wet <- terra::ifel(seafloor >= dmin, 1, NA)
    dmin <- terra::mask(dmin, wet)
    dmax <- terra::mask(terra::ifel(dmax > seafloor, seafloor, dmax), wet)
  }

  out <- c(dmin, dmax)
  names(out) <- c("depth_min", "depth_max")

  out <- methods::new("SpatEnvelope", out)
  methods::validObject(out)
  out
}

# Internal: resolve a depth limit given either as a single number or as a
# single-layer SpatRaster into a named layer on the grid of `template`.
.as_depth_layer <- function(value, name, template) {
  if (inherits(value, "SpatRaster")) {
    if (terra::nlyr(value) != 1) {
      stop("`", name, "` must be a single-layer SpatRaster; got ",
           terra::nlyr(value), " layers.", call. = FALSE)
    }
    if (!terra::compareGeom(value, template, stopOnError = FALSE)) {
      stop("`", name, "` must be on the same grid (CRS, extent, resolution) ",
           "as `x`.", call. = FALSE)
    }
    out <- value
  } else {
    if (!is.numeric(value) || length(value) != 1 || is.na(value)) {
      stop("`", name, "` must be a single non-missing number or a ",
           "single-layer SpatRaster.", call. = FALSE)
    }
    out <- terra::setValues(terra::rast(template), value)
  }
  names(out) <- name
  out
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
