#' Extract raster values from a 3D volume
#'
#' Crop a multi-depth SpatRaster to an area polygon and select depth layers
#' within a given depth range. Layer names must follow the
#' `{variable}_depth={value}` convention (native to WOA NetCDFs); the numeric
#' depth is parsed from each layer name. The nearest available depth layers to
#' `min_depth` and `max_depth` are used as the inclusive bounds, matching the
#' original `woa_volume_extract()` behaviour.
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
  layer_names <- names(rast_3d)
  depths <- suppressWarnings(
    as.numeric(stringr::str_extract(layer_names, "(?<=_depth=)-?[0-9.]+"))
  )
  if (all(is.na(depths))) {
    stop(
      "No layer names match the '{variable}_depth={value}' convention. ",
      "Got: ", paste(utils::head(layer_names), collapse = ", ")
    )
  }

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
#' For one species polygon + depth limits, extract each raster in
#' `raster_list` via [extract_rast_volume()] and compute summary statistics.
#' Apply across species with `lapply()` / `mapply()` in vignettes.
#'
#' For each named raster, returns columns:
#' `{name}_min`, `{name}_max`, `{name}_mean`, `{name}_n_surface_cells`,
#' `{name}_n_cells`, `{name}_n_depths`.
#'
#' @param species_range sf or SpatVector. Single species range polygon.
#' @param min_depth Numeric. Upper (shallower) depth limit (metres).
#' @param max_depth Numeric. Lower (deeper) depth limit (metres).
#' @param raster_list Named list of multi-depth SpatRasters following the
#'   `{variable}_depth={value}` layer naming convention.
#'
#' @returns Single-row data frame of summary statistics across all rasters.
#' @export
summarise_species_environment <- function(species_range, min_depth, max_depth,
                                          raster_list) {
  if (is.null(names(raster_list)) || any(names(raster_list) == "")) {
    stop("raster_list must be fully named.")
  }

  cols <- lapply(names(raster_list), function(nm) {
    r <- raster_list[[nm]]
    extracted <- extract_rast_volume(species_range, min_depth, max_depth, r)
    vals <- terra::values(extracted)

    n_depths <- terra::nlyr(extracted)
    n_cells <- sum(!is.na(vals))
    # Number of surface cells with at least one non-NA depth layer
    any_present <- terra::app(extracted, fun = function(x) as.numeric(any(!is.na(x))))
    n_surface <- sum(terra::values(any_present) > 0, na.rm = TRUE)

    out <- c(
      min  = suppressWarnings(min(vals, na.rm = TRUE)),
      max  = suppressWarnings(max(vals, na.rm = TRUE)),
      mean = suppressWarnings(mean(vals, na.rm = TRUE)),
      n_surface_cells = n_surface,
      n_cells = n_cells,
      n_depths = n_depths
    )
    # Replace Inf/-Inf from empty inputs with NA
    out[is.infinite(out)] <- NA_real_
    names(out) <- paste(nm, names(out), sep = "_")
    as.list(out)
  })

  as.data.frame(unlist(cols, recursive = FALSE), stringsAsFactors = FALSE)
}
