# Constructors 

#' Coerce a 2D footprint to a 2.5D min-max envelope
#'
#' Build a [SpatEnvelope-class] — one continuous `[depth_min, depth_max]`
#' interval per grid cell — from a 2D horizontal footprint and the depth limits
#' that apply to it. This is the general form of the conversion
#' [vect_to_envelope()] performs for polygons: any 2D raster whose non-`NA`
#' cells mark presence becomes a 3D domain once depth limits are attached to
#' it.
#'
#' `x` is the footprint. Its values are not read, only their non-`NA` pattern:
#' a rasterized species range, a Global Fishing Watch effort layer, or a plain
#' presence mask all work. A SpatRaster that *already* has exactly the two
#' layers `depth_min` and `depth_max` (the output of [vect_to_envelope()], or a
#' [SpatEnvelope-class] itself) is promoted directly instead, in which case
#' `depth_min` and `depth_max` must be omitted.
#'
#' Depths are positive metres increasing downward, following the package's
#' depth sign convention. Flip GEBCO-style elevation first, e.g.
#' `terra::clamp(-terra::project(bathy, x), lower = 0)`, which gives a positive
#' seafloor depth with land clamped to 0.
#'
#' @param x SpatRaster. Either a single-layer footprint whose non-`NA` cells are
#'   present, or a two-layer raster already named `depth_min`, `depth_max`.
#' @param depth_min,depth_max Shallowest and deepest depth in metres, positive
#'   down. Each is either a single number applying to the whole footprint, or a
#'   single-layer SpatRaster on the grid of `x` giving the limit per cell. Omit
#'   both when `x` already carries the two depth layers.
#'
#' @returns A [SpatEnvelope-class] with layers `depth_min` and `depth_max`, on
#'   the grid of `x`.
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
#' # Per-cell limits are allowed too, as single-layer rasters.
#' dmax <- terra::setValues(terra::rast(fp), c(100, 200, 300, 400))
#' terra::values(as_envelope(fp, depth_min = 10, depth_max = dmax))
#' @export
as_envelope <- function(x, depth_min, depth_max) {
  if (inherits(x, "sf") || inherits(x, "sfc") || inherits(x, "SpatVector")) {
    stop("`x` must be a SpatRaster footprint, not vector geometry. ",
         "Rasterize the polygons onto the study grid first, or use ",
         "vect_to_envelope(), which does both.", call. = FALSE)
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

  # Check dmin and dmax layers 
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
#' 
#' Expand a [SpatEnvelope-class] to the [SpatVoxel-class], with an input of
#' depth levels. A depth level belongs to a cell when it falls inside that
#' cell's `[depth_min, depth_max]` interval, inclusive of both ends; depths
#' outside the interval, and cells that are `NA` in the envelope, are `NA` in
#' every layer.
#'
#' `fun` supplies the values written at the levels a cell occupies, and so
#' controls what the voxel *means*. The default writes `1` at every occupied
#' level, giving a presence voxel — the direct 3D form of the envelope. A
#' function of the occupied depths instead writes a vertical profile, which is
#' what vertical-migration work needs: pass the share of time spent at each
#' depth and the voxel carries that distribution rather than bare presence.
#' `fun` is called once per distinct envelope interval on the grid, not once
#' per cell, since its result depends only on which depths are inside.
#'
#' The expansion is limited by the levels on offer: a cell whose envelope
#' contains none of `depths` — an interval of `[10, 20]` against levels
#' `c(0, 100)`, say — has no layer to be recorded in and comes back empty. That
#' is the resolution cost of the voxel form, and is warned about rather than
#' passed over in silence.
#'
#' @param x SpatEnvelope, e.g. from [as_envelope()] or [voxel_to_envelope()].
#' @param depths Array of values that can be coerced into numeric type,
#'   represents metres depth below sea level. Sorted shallow to deep, and
#'   deduplicated, before use.
#' @param fun Function taking the depths inside a cell's envelope and returning
#'   the values to write at them: either one value per depth, or a single value
#'   used at all of them. Defaults to `1` between `depth_min` and `depth_max`
#'   of SpatEnvelope type.
#' @param varname Name to use for depth layer, taking on form of `{varname}_depth={depths[i]}`
#'
#' @returns A [SpatVoxel-class] with one layer per depth in `depths`, on the
#'   grid of `x`, layers ordered shallow to deep.
#'
#' @seealso [voxel_to_envelope()], the reverse (and lossy) collapse.
#'
#' @examples
#' fp <- terra::rast(nrows = 1, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 1)
#' terra::values(fp) <- c(1, NA)
#' e <- as_envelope(fp, depth_min = 50, depth_max = 200)
#'
#' # presence at every standard depth the envelope covers
#' terra::values(envelope_to_voxel(e, depths = c(0, 50, 100, 200, 300)))
#'
#' # a vertical profile instead: the share of time spent at each occupied depth
#' terra::values(
#'   envelope_to_voxel(e, depths = c(0, 50, 100, 200, 300),
#'                     fun = function(d) rep(1 / length(d), length(d)),
#'                     varname = "time")
#' )
#' @export
envelope_to_voxel <- function(x, depths, fun = function(depths) {1}, varname = "presence") {
  if (!is(x, "SpatEnvelope")) {
    stop("Input error for envelope_to_voxel(): `x` needs to be of ",
         "`SpatEnvelope` class.", call. = FALSE)
  }
  # Coercion, not class: an integer vector, or a character vector of numbers,
  # is as good as a double here — "hello" is not a depth.
  depths <- suppressWarnings(as.numeric(depths))
  if (length(depths) == 0 || anyNA(depths)) {
    stop("Input error for envelope_to_voxel(): `depths` needs to be array ",
         "coercible to numeric type.", call. = FALSE)
  }
  if (!is.function(fun)) {
    stop("Input error for envelope_to_voxel(): `fun` needs to be a function.",
         call. = FALSE)
  }
  if (!is.character(varname) || length(varname) != 1 || is.na(varname)) {
    stop("Input error for envelope_to_voxel(): `varname` needs to be a string.",
         call. = FALSE)
  }
  if (any(depths < 0)) {
    stop("Input error for envelope_to_voxel(): depths are positive metres ",
         "increasing downward; got ", paste(depths[depths < 0], collapse = ", "),
         ".", call. = FALSE)
  }

  # A voxel's layer axis is one layer per depth, shallow to deep, so the
  # requested levels are put in that form up front.
  depths <- sort(unique(depths))
  n_depths <- length(depths)

  dmin <- terra::values(x[["depth_min"]], mat = FALSE)
  dmax <- terra::values(x[["depth_max"]], mat = FALSE)

  # The levels a cell occupies are always a contiguous run of `depths`, because
  # an envelope is a single solid interval. Recording that run as its first and
  # last index avoids building a cells-by-depths logical matrix.
  first <- findInterval(dmin, depths, left.open = TRUE) + 1L  # first depth >= dmin
  last <- findInterval(dmax, depths)                          # last depth <= dmax
  occupied <- !is.na(first) & !is.na(last) & first <= last

  # Present in the envelope, but no requested depth level lies inside it.
  n_missed <- sum(!is.na(dmin) & !is.na(dmax) & !occupied)
  if (n_missed > 0) {
    warning(n_missed, " cell(s) have an envelope that contains none of ",
            "`depths` and are empty in the voxel. Supply finer depth levels ",
            "to resolve them.", call. = FALSE)
  }

  out <- matrix(NA_real_, nrow = length(dmin), ncol = n_depths)

  # Cells sharing an interval share a profile, so `fun` is evaluated per
  # distinct interval. A grid holds far fewer of those than it does cells.
  interval <- first * (n_depths + 1L) + last
  for (cells in split(which(occupied), interval[occupied])) {
    levels_in <- first[cells[1]]:last[cells[1]]
    vals <- fun(depths[levels_in])

    if (!is.numeric(vals) && !is.logical(vals)) {
      stop("`fun` must return numeric values for the depths it is given; got ",
           paste(class(vals), collapse = "/"), ".", call. = FALSE)
    }
    if (length(vals) != 1 && length(vals) != length(levels_in)) {
      stop("`fun` must return one value per depth, or a single value for all ",
           "of them; got ", length(vals), " values for ", length(levels_in),
           " depths.", call. = FALSE)
    }

    # Column-major fill: `each` repeats a depth's value down the cells sharing
    # this interval, matching how the target submatrix is laid out.
    out[cells, levels_in] <- rep(as.numeric(vals), each = length(cells))
  }

  v <- terra::rast(terra::rast(x[["depth_min"]]), nlyrs = n_depths)
  terra::values(v) <- out
  names(v) <- paste0(varname, "_depth=", depths)

  as_voxel(v)
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
  n_cells <- terra::ncell(v)
  n_depths <- length(depths)

  # Hit matrix (cells x depths): does `fun` hold for this cell at this depth?
  # The stack is read once and `fun` is still applied one depth layer at a
  # time, so a predicate that reduces over a layer (e.g. `\(x) x > mean(x)`)
  # keeps its per-depth meaning. `fun` is evaluated on the values rather than
  # on the SpatRaster so that any ordinary R predicate works, not only
  # terra-aware ones.
  vals <- terra::values(v)
  hit <- matrix(FALSE, nrow = n_cells, ncol = n_depths)
  for (i in seq_len(n_depths)) {
    h <- as.logical(fun(vals[, i]))
    if (length(h) != n_cells) {
      stop("`fun` must return one TRUE/FALSE per cell value; got ",
           length(h), " values for ", n_cells, " cells.",
           call. = FALSE)
    }
    h[is.na(h)] <- FALSE
    hit[, i] <- h
  }
  rm(vals)

  # `SpatVoxel` validity guarantees depths are non-NA and sorted shallow to
  # deep, so each row's first and last TRUE column are exactly the envelope
  # bounds. `max.col()` finds them at C level, which avoids building one
  # full-size intermediate raster per depth.
  first_hit <- max.col(hit, ties.method = "first")
  last_hit <- max.col(hit, ties.method = "last")

  # An all-FALSE row still yields a column index, so cells where the predicate
  # never holds must go back to NA rather than point at the shallowest depth.
  never <- !hit[cbind(seq_len(n_cells), first_hit)]
  depth_min <- depths[first_hit]
  depth_max <- depths[last_hit]
  depth_min[never] <- NA_real_
  depth_max[never] <- NA_real_

  out <- terra::setValues(terra::rast(v[[1]], nlyrs = 2),
                          cbind(depth_min, depth_max))
  names(out) <- c("depth_min", "depth_max")

  out <- methods::new("SpatEnvelope", out)
  methods::validObject(out)
  out
}

# Internal: validate and normalise the `depth_min` / `depth_max` inputs of
# `vect_to_envelope()`. Accepts a list, a numeric vector, or a SpatRaster
# Returns a list whose elements can be used in `do.call("max", ...)` / `do.call("min", ...)`.
.normalize_depth_inputs <- function(x, template, arg) {
  if (inherits(x, "SpatRaster")) {
    x <- list(x)
  } else if (!is.list(x)) {
    x <- as.list(x)
  }

  if (length(x) == 0L) {
    stop("`", arg, "` is empty. Supply at least one numeric value or SpatRaster.", call. = FALSE)
  }

  for (i in seq_along(x)) {
    el <- x[[i]]
    label <- if (length(x) == 1L) {
      paste0("`", arg, "`")
    } else {
      paste0("`", arg, "` element ", i)
    }

    if (inherits(el, "SpatRaster")) {
      if (!terra::same.crs(el, template)) {
        stop(label, " has a different CRS than `template`. ",
             "Project it onto the template grid first.", call. = FALSE)
      }
      aligned <- terra::compareGeom(el, template, crs = FALSE,
                                    stopOnError = FALSE, messages = FALSE)
      if (!isTRUE(aligned)) {
        stop(label, " does not align with `template`; its extent or resolution ",
             "differs. Resample it onto the template grid first.", call. = FALSE)
      }
    } else if (!is.numeric(el)) {
      stop(label, " must be numeric or a SpatRaster, not ", class(el)[1], ".",
           call. = FALSE)
    } else if (anyNA(el)) {
      # A scalar NA carries no information but, under `na.rm = FALSE`, would
      # blank every cell of the output. Reject it here where we can say which
      # argument was at fault instead of reporting an empty envelope later.
      stop(label, " is NA. Drop it, or supply a real depth constraint.",
           call. = FALSE)
    }
  }

  x
}

# Internal: collapse the validated `depth_min` / `depth_max` constraints of
# `vect_to_envelope()` into one SpatRaster on the `template` grid, applying
# `fun` across them cell by cell ("max" for depth_min, "min" for depth_max, so
# that every constraint narrows the envelope).
.combine_depths <- function(x, template, fun) {
  # identify which inputs are SpatRaster, which are not 
  is_rast <- vapply(x, function(el) inherits(el, "SpatRaster"), logical(1))

  # skips the reordered do.call when there are no rasters in input list x
  # creates raster with single value across
  if (!any(is_rast)) {
    return(terra::setValues(terra::rast(template[[1]]), do.call(fun, x)))
  }
  # terra has min() and max() functions that can apply to a list that includes
  # both SpatRaster and numeric values. However, it only works when the SpatRaster
  # is first in the list; the base::min is called instead if the first element is 
  # a numeric object. This do.call line takes the reordered input list, with the 
  # SpatRaster objects first. 

  # `na.rm = FALSE` so that cell where constraints / depth raster
  # has NA value keeps it in the output raster. Avoids filling the value from 
  # remaining constraints
  do.call(fun, c(x[is_rast], x[!is_rast], list(na.rm = FALSE)))
}

#' Convert SpatVector or sf to SpatEnvelope
#' 
#' Rasterize polygons onto a template raster grid and assign per-cell depth limits,
#' outputting an SpatEnvelope object. The depths are clamped by depth_min (shallowest) 
#' and depth_max (deepest), and/or by rasters (ex. bathymetry) that are the same 
#' coordinate and resolution as the template. Where a constraint raster is NA at
#' a cell its limit there is unknown, so the cell is dropped rather than falling
#' back to the remaining constraints.
#' 
#' @param polygon sf or SpatVector, for example species ranges or fishery footprints. 
#' @param template SpatRaster that defines the horizontal grid of the SpatEnvelope output. 
#' @param depth_min List. Can contain both numeric and SpatRasters that match CRS, 
#'   resolution, extent of `template`` and contain numeric values. For each cell, the maximum
#'   across the `depth_min` list parameters is used as output SpatEnvelope depth_min layer cell
#'   value. 
#' @param depth_max List. Can contain both numeric and SpatRasters that match CRS, 
#'   resolution, extent of `template`` and contain numeric values. For each cell, the minimum
#'   across the `depth_max` list parameters is used as output SpatEnvelope depth_max layer cell
#'   value. Note that when `depth_min` is exactly `depth_max`, these cell values are dropped and
#'   replaced with NA.
#' 
#' @returns SpatEnvelope, with depth_min and depth_max layers. 
#' @export
vect_to_envelope <- function(polygon, template, depth_min, depth_max) {
  # check params
  if (!inherits(polygon, c("sf", "sfc", "SpatVector"))) {
    stop("`polygon` needs to be of class SpatVector, sf, or sfc")
  }
  if (inherits(polygon, "sf") || inherits(polygon, "sfc")) {
    polygon <- terra::vect(polygon)
  }
  if (!is(template, "SpatRaster")) {
    stop("`template` needs to be of class SpatRaster")
  }
  if(!terra::same.crs(crs(polygon), crs(template))) {
    stop("`polygon` and `template` have different CRS.")
  }

  # check the depth inputs for CRS, resolution, extent matching and reject NA params
  depth_min <- .normalize_depth_inputs(depth_min, template, "depth_min")
  depth_max <- .normalize_depth_inputs(depth_max, template, "depth_max")

  # take first layer in case multi-layer raster
  all_one <- template[[1]]
  # make all cell values 1, since mask leaves NAs alone 
  terra::values(all_one) <- 1
  # intersect between polygon and template
  masked <- terra::mask(all_one, polygon) 
  if(terra::global(masked, "notNA")[1,1] == 0) {
    stop("All output cell values are NA. `polygon` and `template` may not spatially overlap.")
  }

  # Creating depth_min, depth_max rasters that form the SpatEnvelope output
  # - value that narrows the envelope the most is selected
  # - preserves NA values from the constraints, rather than fall back on other constraints
  # deepest of depth_min constraints
  depth_min_rast <- .combine_depths(depth_min, template, "max") %>%
    mask(masked)
  # shallowest of depth_max constraints
  depth_max_rast <- .combine_depths(depth_max, template, "min") %>%
    mask(masked)

  # check for validity, where depth_max is greater than depth_min
  diffs <- depth_max_rast - depth_min_rast
  msk <- ifel(diffs > 0, 1, NA)
  if(terra::global(msk, "notNA")[1,1] == 0) {
    warning("All depth_max values are shallower than depth_min. Check `depth_min` and `depth_max`, you may have swapped these two.")
  }

  # mask cells that are not valid, depth_min is deeper than depth_max
  depth_min_rast <- mask(depth_min_rast, msk)
  depth_max_rast <- mask(depth_max_rast, msk)

  # assign SpatEnvelope class to output
  out <- rast(c(depth_min = depth_min_rast, depth_max = depth_max_rast)) %>% as_envelope()
  out
}

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
