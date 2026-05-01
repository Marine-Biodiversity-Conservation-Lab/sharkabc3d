#' Mask a 3D raster by a rasterized species range
#'
#' Given a multi-depth environmental raster (`rast_3d`) and a rasterized range
#' (`range_rast`, the output of [rasterize_range()] with per-cell `depth_min`
#' and `depth_max` layers clamped to bathymetry), return a 3D raster where
#' each cell retains the environmental value only at depths inside that
#' cell's `[depth_min, depth_max]` window. Cells outside the range are NA
#' across all depth layers.
#'
#' This preserves per-cell vertical refuge — e.g., a species whose maximum
#' depth is 1000 m but the seafloor is 400 m will only "see" the 0-400 m
#' layers at that cell. Used as the underlying extractor for species-range
#' depth profiles and range-aware environmental summaries.
#'
#' `range_rast` and `rast_3d` must share extent, resolution, and CRS. The
#' caller is responsible for alignment (typically by rasterizing onto a grid
#' derived from `rast_3d`, or by pre-projecting with
#' `terra::project(range_rast, rast_3d[[1]], method = "near")`).
#'
#' @param range_rast SpatRaster. Output of [rasterize_range()] with layers
#'   `depth_min` and `depth_max` in metres.
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following
#'   the `{variable}_depth={value}` convention.
#'
#' @returns SpatRaster with the same layers as `rast_3d`, masked to the
#'   per-cell depth window of `range_rast`.
#' @export
extract_rast_range <- function(range_rast, rast_3d) {
  if (!all(c("depth_min", "depth_max") %in% names(range_rast))) {
    stop("range_rast must have 'depth_min' and 'depth_max' layers ",
         "(from rasterize_range()).", call. = FALSE)
  }

  depths <- .parse_depth_layers(rast_3d)

  if (!terra::compareGeom(rast_3d[[1]], range_rast[[1]],
                          stopOnError = FALSE, messages = FALSE)) {
    stop(
      "range_rast and rast_3d are not aligned (extent, resolution, or CRS ",
      "differs). Pre-project the range onto the 3D raster's grid, e.g.:\n  ",
      "range_rast <- terra::project(range_rast, rast_3d[[1]], method = \"near\")",
      call. = FALSE
    )
  }

  dmin <- range_rast[["depth_min"]]
  dmax <- range_rast[["depth_max"]]

  masked <- lapply(seq_along(depths), function(i) {
    # Put the SpatRaster on the left of every comparison — terra's
    # scalar-on-left comparison can drop equality boundaries.
    in_window <- !is.na(dmin) & !is.na(dmax) &
                 dmin <= depths[i] & dmax >= depths[i]
    terra::mask(rast_3d[[i]], terra::ifel(in_window, 1, NA))
  })

  out <- terra::rast(masked)
  names(out) <- names(rast_3d)
  out
}

# Internal: parse numeric depths from the `{variable}_depth={value}` layer
# naming convention used throughout the package. Returns a numeric vector the
# same length as `nlyr(rast)`; errors if no layer matches the convention.
.parse_depth_layers <- function(rast) {
  layer_names <- names(rast)
  depths <- suppressWarnings(
    as.numeric(stringr::str_extract(layer_names, "(?<=_depth=)-?[0-9.]+"))
  )
  if (all(is.na(depths))) {
    stop(
      "No layer names match the '{variable}_depth={value}' convention. ",
      "Got: ", paste(utils::head(layer_names), collapse = ", "),
      call. = FALSE
    )
  }
  depths
}

#' Extract raster values from a 3D volume
#'
#' Crop a multi-depth SpatRaster to an area polygon and select depth layers
#' within a given depth range. Layer names must follow the
#' `{variable}_depth={value}` convention (native to WOA NetCDFs); the numeric
#' depth is parsed from each layer name. The nearest available depth layers to
#' `min_depth` and `max_depth` are used as the inclusive bounds.
#'
#' @param area sf or SpatVector. Area polygon to crop the raster to.
#' @param min_depth Numeric. Shallowest depth (metres).
#' @param max_depth Numeric. Deepest depth (metres).
#' @param rast_3d SpatRaster. Multi-depth raster with `{variable}_depth={value}`
#'   layer names.
#'
#' @returns SpatRaster cropped to `area` and filtered to the depth range.
#' @export
extract_rast_volume <- function(area, min_depth, max_depth, rast_3d) {
  depths <- .parse_depth_layers(rast_3d)

  idx_min <- which.min(abs(depths - min_depth))
  idx_max <- which.min(abs(depths - max_depth))
  idx <- sort(c(idx_min, idx_max))
  selected <- rast_3d[[seq.int(idx[1], idx[2])]]

  # Reproject/convert area to raster CRS if necessary
  if (inherits(area, "sf")) {
    area <- terra::vect(area)
  }
  if (terra::crs(area) != terra::crs(selected) && terra::crs(area) != "") {
    area <- terra::project(area, terra::crs(selected))
  }

  terra::crop(selected, area, mask = TRUE, touches = TRUE)
}

#' Summarise environmental conditions within a species' 3D range
#'
#' Takes a rasterized species range (output of [rasterize_range()] with
#' per-cell `depth_min`/`depth_max` clamped to bathymetry) and a named list
#' of multi-depth environmental rasters. For each environmental raster,
#' values are restricted to cells + depths inside the species' per-cell
#' depth window via [extract_rast_range()] before summary statistics are
#' computed. Apply across species with `lapply()` / `mapply()` in vignettes.
#'
#' All rasters in `raster_list` must share extent, resolution, and CRS with
#' `range_rast`. Pre-align heterogeneous environmental rasters onto a common
#' grid before calling.
#'
#' For each named raster, returns columns:
#' `{name}_min`, `{name}_max`, `{name}_mean`, `{name}_n_surface_cells`,
#' `{name}_n_cells`, `{name}_n_depths`.
#'
#' @param range_rast SpatRaster. Output of [rasterize_range()] with
#'   `depth_min` and `depth_max` layers.
#' @param raster_list Named list of multi-depth SpatRasters following the
#'   `{variable}_depth={value}` layer naming convention.
#'
#' @returns Single-row data frame of summary statistics across all rasters.
#' @export
summarise_species_environment <- function(range_rast, raster_list) {
  if (is.null(names(raster_list)) || any(names(raster_list) == "")) {
    stop("raster_list must be fully named.")
  }

  # Fail fast if any env raster isn't aligned with range_rast. Avoids
  # surfacing extract_rast_range()'s per-raster alignment error halfway
  # through a long loop.
  mismatched <- vapply(names(raster_list), function(nm) {
    !terra::compareGeom(range_rast[[1]], raster_list[[nm]][[1]],
                        stopOnError = FALSE, messages = FALSE)
  }, logical(1))
  if (any(mismatched)) {
    stop(
      "These rasters in raster_list are not aligned with range_rast ",
      "(extent, resolution, or CRS differs):\n  ",
      paste(names(raster_list)[mismatched], collapse = ", "),
      "\nPre-project all environmental rasters onto a common grid, e.g.: ",
      "terra::project(r, range_rast[[1]], method = \"near\").",
      call. = FALSE
    )
  }

  cols <- lapply(names(raster_list), function(nm) {
    masked <- extract_rast_range(range_rast, raster_list[[nm]])
    vals <- terra::values(masked)

    n_depths <- terra::nlyr(masked)
    n_cells <- sum(!is.na(vals))
    # Number of surface cells with at least one non-NA depth layer
    any_present <- terra::app(masked,
                              fun = function(x) as.numeric(any(!is.na(x))))
    n_surface <- sum(terra::values(any_present) > 0, na.rm = TRUE)

    out <- c(
      min  = suppressWarnings(min(vals, na.rm = TRUE)),
      max  = suppressWarnings(max(vals, na.rm = TRUE)),
      mean = suppressWarnings(mean(vals, na.rm = TRUE)),
      n_surface_cells = n_surface,
      n_cells = n_cells,
      n_depths = n_depths
    )
    out[is.infinite(out)] <- NA_real_
    names(out) <- paste(nm, names(out), sep = "_")
    as.list(out)
  })

  as.data.frame(unlist(cols, recursive = FALSE), stringsAsFactors = FALSE)
}
