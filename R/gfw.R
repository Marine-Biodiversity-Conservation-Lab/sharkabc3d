# ---------------------------------------------------------------------------
# Global Fishing Watch (GFW) apparent fishing effort utilities.
#
# Ingest is delegated to the `gfwr` package, which queries the GFW 4Wings
# API and returns a long-format tibble of apparent fishing hours per cell,
# already aggregated server-side by the chosen `group_by`. The helpers
# below cover the gap between that tibble and the package's depth-aware
# pipeline:
#
#   - `gfw_effort_to_raster()` rasterises the gfwr tibble onto the study
#     grid as a multi-layer SpatRaster (one layer per group level).
#   - `gfw_gear_depth_bands()` extends a per-geartype effort raster into
#     a depth-stratified stack by combining a user-supplied gear →
#     depth-band lookup with bathymetry, producing layers in the
#     package-standard `effort_<geartype>_depth=<value>` convention.
#
# This package intentionally does not ship a built-in gear → depth-band
# lookup. Operating depths vary by region, fleet, and time, and the
# right values for any given analysis depend on assumptions the analyst
# is responsible for. The vignette demonstrates the schema with
# placeholder values; users should supply their own.
# ---------------------------------------------------------------------------

#' Rasterise a GFW effort tibble onto a target grid
#'
#' Turn the long-format apparent-fishing-hours tibble returned by
#' `gfwr::gfw_ais_fishing_hours()` (formerly `gfwr::get_raster()`) into a
#' multi-layer SpatRaster on the package's canonical study grid. Each
#' level of `layer_by` becomes its own layer, named
#' `effort_<level>` (e.g. `effort_drifting_longlines`).
#'
#' The input is expected to carry a cell centroid (`Lat`, `Lon`), a value
#' column (default `"Apparent Fishing Hours"`), and one categorical column
#' matching the API's `group_by` — for example `geartype` or `flag` (note
#' lower-case; this is what `gfwr` actually returns). Records that fall
#' into the same target cell × layer level are aggregated with `fun`.
#'
#' @param effort Data frame. Output of `gfwr::gfw_ais_fishing_hours()` (a
#'   long-format tibble with at minimum `Lat`, `Lon`, a value, and a
#'   grouping column).
#' @param grid SpatRaster. Target grid (extent, resolution, CRS) — typically
#'   the same grid used for species ranges and WOA extraction.
#' @param layer_by Character. Column in `effort` whose levels become layers.
#'   `NULL` produces a single-layer total-effort raster. Default
#'   `"geartype"`.
#' @param value Character. Column in `effort` to aggregate. Default
#'   `"Apparent Fishing Hours"`.
#' @param fun Character or function. Aggregation applied to records that
#'   fall into the same cell × layer level. Default `"sum"`.
#'
#' @returns A SpatRaster with one layer per `layer_by` level (or one layer
#'   if `layer_by = NULL`). Layer names follow `effort_<level>`.
#' @export
gfw_effort_to_raster <- function(effort,
                                 grid,
                                 layer_by = "geartype",
                                 value = "Apparent Fishing Hours",
                                 fun = "sum") {
  effort <- as.data.frame(effort)
  required <- c("Lat", "Lon", value, layer_by)
  missing_cols <- setdiff(required, names(effort))
  if (length(missing_cols) > 0) {
    stop(
      "effort is missing required columns: ",
      paste(missing_cols, collapse = ", "),
      call. = FALSE
    )
  }

  pts_df <- data.frame(
    x = effort$Lon,
    y = effort$Lat,
    v = effort[[value]]
  )
  if (!is.null(layer_by)) {
    pts_df$grp <- effort[[layer_by]]
  }

  pts <- terra::vect(
    pts_df,
    geom = c("x", "y"),
    crs = "EPSG:4326",
    keepgeom = FALSE
  )
  if (!terra::same.crs(pts, grid)) {
    pts <- terra::project(pts, terra::crs(grid))
  }

  if (is.null(layer_by)) {
    out <- terra::rasterize(pts, grid, field = "v", fun = fun, background = NA)
    names(out) <- "effort"
  } else {
    out <- terra::rasterize(
      pts, grid,
      field = "v", fun = fun, by = "grp", background = NA
    )
    names(out) <- paste0("effort_", names(out))
  }
  out
}

#' Build a depth-stratified fishing-effort stack for one gear class
#'
#' Combine a single-gear effort raster (one layer, e.g. one slice of the
#' output of [gfw_effort_to_raster()]) with a bathymetry layer and a
#' user-supplied gear → depth-band lookup to produce a stack of rasters
#' representing *where this gear's effort occurs in the water column*.
#'
#' Processes one gear at a time so peak memory scales with a single
#' gear's depth-stratified stack rather than every gear at once. To build
#' the full multi-gear `effort_3d` stack, call this in a loop and combine
#' (e.g. `do.call(c, unname(list_of_stacks))`); writing intermediate
#' results to disk between iterations keeps a large analysis bounded —
#' see the vignette `gfw-fishing-effort-3d` for the standard pattern.
#'
#' For the operating depth window:
#' \itemize{
#'   \item `mode = "pelagic"` — constant `[depth_min, depth_max]` from the lookup.
#'   \item `mode = "benthic"` — window is `[max(bathymetry - benthic_buffer, 0),
#'     bathymetry]` per cell, i.e. a thin band riding the seafloor.
#'   \item `mode = "midwater"` / `"unknown"` — handled per `fallback`.
#' }
#'
#' The window is intersected with `standard_depths` to decide which depth
#' layers receive effort. Output layer names follow the package-standard
#' `effort_<gear>_depth=<value>` convention.
#'
#' @param effort_layer SpatRaster. Single-layer effort raster for one
#'   gear, e.g. `effort_by_gear[[paste0("effort_", gear)]]`.
#' @param gear Character. Gear class label. Used to look up the depth band
#'   in `depth_lookup` and to construct output layer names.
#' @param bathymetry SpatRaster. Positive-down seafloor depth (m), aligned
#'   to `effort_layer`.
#' @param standard_depths Numeric vector. Depth levels (m, positive down)
#'   at which the output stack is produced (e.g. WOA23 standard depths).
#' @param depth_lookup Data frame. User-supplied gear → depth-band mapping.
#'   No default is provided: operating depths vary by region, fleet, and
#'   time, and the appropriate values for any given analysis are the
#'   analyst's call. Required columns:
#'   \itemize{
#'     \item `geartype` — GFW gear class string (e.g. `"drifting_longlines"`).
#'     \item `depth_min` — Shallowest operating depth (m, positive down).
#'       `NA` when `mode = "benthic"` or `"unknown"`.
#'     \item `depth_max` — Deepest operating depth (m, positive down).
#'       `NA` when `mode = "benthic"` or `"unknown"`.
#'     \item `mode` — One of `"pelagic"`, `"benthic"`, `"midwater"`, or
#'       `"unknown"`.
#'     \item `benthic_buffer` — For `mode = "benthic"`, metres above the
#'       seafloor the gear is assumed to fish. `NA` otherwise.
#'   }
#'   The single row whose `geartype` matches `gear` is selected.
#' @param allocation Character. `"uniform"` (split evenly across in-band
#'   depths, preserves total effort-hours) or `"presence"` (full value at
#'   every in-band depth — double-counts; use only for footprint maps).
#'   Default `"uniform"`.
#' @param fallback Character. Behaviour for `mode = "unknown"`:
#'   `"drop"` returns `NULL` (caller is expected to skip), `"surface"`
#'   treats the gear as 0-m surface effort. Default `"drop"`.
#'
#' @returns A SpatRaster with `length(standard_depths)` layers named
#'   `effort_<gear>_depth=<value>`, or `NULL` when `mode = "unknown"`
#'   and `fallback = "drop"`. A `depth_band` attribute (single-row data
#'   frame) records the band actually used.
#' @export
gfw_gear_depth_bands <- function(effort_layer,
                                 gear,
                                 bathymetry,
                                 standard_depths,
                                 depth_lookup,
                                 allocation = "uniform",
                                 fallback = "drop") {
  allocation <- match.arg(allocation, c("uniform", "presence"))
  fallback <- match.arg(fallback, c("drop", "surface"))

  required_cols <- c("geartype", "depth_min", "depth_max", "mode",
                     "benthic_buffer")
  missing_cols <- setdiff(required_cols, names(depth_lookup))
  if (length(missing_cols) > 0) {
    stop("depth_lookup is missing required columns: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }
  if (terra::nlyr(effort_layer) != 1) {
    stop("effort_layer must be a single-layer SpatRaster.", call. = FALSE)
  }
  if (terra::nlyr(bathymetry) != 1) {
    stop("bathymetry must be a single-layer SpatRaster.", call. = FALSE)
  }
  if (!terra::compareGeom(bathymetry, effort_layer, stopOnError = FALSE)) {
    stop(
      "bathymetry must align (CRS, resolution, extent) with effort_layer.",
      call. = FALSE
    )
  }

  standard_depths <- sort(unique(standard_depths))
  if (length(standard_depths) == 0) {
    stop("standard_depths must be non-empty.", call. = FALSE)
  }
  if (any(standard_depths < 0)) {
    stop("standard_depths must be non-negative (positive-down depth in m).",
         call. = FALSE)
  }

  lookup <- depth_lookup[depth_lookup$geartype == gear, ]
  if (nrow(lookup) == 0) {
    stop("no depth_lookup entry for gear: ", gear, call. = FALSE)
  }
  if (nrow(lookup) > 1) {
    stop("Multiple depth_lookup entries for gear: ", gear, call. = FALSE)
  }

  mode <- as.character(lookup$mode)

  if (mode %in% c("pelagic", "midwater")) {
    out <- build_pelagic_stack(
      effort_layer, gear,
      depth_min = lookup$depth_min,
      depth_max = lookup$depth_max,
      standard_depths = standard_depths,
      allocation = allocation
    )
    band <- data.frame(
      geartype = gear,
      depth_min_used = lookup$depth_min,
      depth_max_used = lookup$depth_max,
      mode = mode,
      stringsAsFactors = FALSE
    )
  } else if (mode == "benthic") {
    out <- build_benthic_stack(
      effort_layer, gear,
      buffer = lookup$benthic_buffer,
      bathymetry = bathymetry,
      standard_depths = standard_depths,
      allocation = allocation
    )
    band <- data.frame(
      geartype = gear,
      depth_min_used = NA_real_,
      depth_max_used = NA_real_,
      mode = "benthic",
      stringsAsFactors = FALSE
    )
  } else if (mode == "unknown") {
    if (fallback == "drop") return(invisible(NULL))
    out <- build_pelagic_stack(
      effort_layer, gear,
      depth_min = 0,
      depth_max = 0,
      standard_depths = standard_depths,
      allocation = allocation
    )
    band <- data.frame(
      geartype = gear,
      depth_min_used = 0,
      depth_max_used = 0,
      mode = "unknown(fallback=surface)",
      stringsAsFactors = FALSE
    )
  } else {
    stop("Unrecognised mode '", mode, "' for gear: ", gear, call. = FALSE)
  }

  attr(out, "depth_band") <- band
  out
}

#' Build a depth-stratified stack for a pelagic (fixed-band) gear
#'
#' Internal helper for [gfw_gear_depth_bands()]. Distributes a single
#' gear's effort layer across the depth layers in `standard_depths` that
#' fall within the fixed band `[depth_min, depth_max]`. Out-of-band
#' depth layers are emitted as all-NA so the output stack has a
#' predictable shape (one layer per `standard_depths` entry).
#'
#' @param layer SpatRaster (single layer). Per-cell effort for one gear.
#' @param gear Character. Gear name (used only to construct layer names
#'   and error messages).
#' @param depth_min,depth_max Numeric scalars. Pelagic operating band, m,
#'   positive down.
#' @param standard_depths Numeric vector. Depth levels at which output
#'   layers are produced. Must already be sorted and non-negative.
#' @param allocation `"uniform"` (split evenly across in-band depths,
#'   preserves total effort-hours) or `"presence"` (full value at every
#'   in-band depth).
#'
#' @returns A SpatRaster with `length(standard_depths)` layers, named
#'   `effort_<gear>_depth=<value>`. Layers outside the band are all-NA.
#' @keywords internal
#' @noRd
build_pelagic_stack <- function(layer, gear, depth_min, depth_max,
                                standard_depths, allocation) {
  in_band <- standard_depths >= depth_min & standard_depths <= depth_max
  n_in_band <- sum(in_band)
  if (n_in_band == 0) {
    stop(
      "Gear '", gear, "' has no standard_depths within band [",
      depth_min, ", ", depth_max, "].",
      call. = FALSE
    )
  }
  share <- if (allocation == "uniform") 1 / n_in_band else 1

  # Per-depth multiplier: `share` in-band, NA out-of-band. Multiplying the
  # single-layer effort raster by each scalar gives the per-depth output
  # layer in one step; concatenating with `terra::rast()` allocates the
  # 57-layer stack once instead of n times via `Reduce(c, ...)`.
  mults <- ifelse(in_band, share, NA_real_)
  out <- terra::rast(lapply(mults, function(m) layer * m))
  names(out) <- paste0("effort_", gear, "_depth=", standard_depths)
  out
}

#' Build a depth-stratified stack for a benthic (bathymetry-clamped) gear
#'
#' Internal helper for [gfw_gear_depth_bands()]. For each cell, the gear's
#' band is `[max(bathymetry - buffer, 0), bathymetry]`. The cell's effort
#' is allocated to those `standard_depths` that fall inside that per-cell
#' band — uniformly (preserving total hours) or as full presence.
#'
#' @param layer SpatRaster (single layer). Per-cell effort for one gear.
#' @param gear Character. Gear name (used only for layer names and errors).
#' @param buffer Numeric scalar. Metres above the seafloor the gear is
#'   assumed to fish.
#' @param bathymetry SpatRaster (single layer). Positive-down seafloor
#'   depth, aligned to `layer`.
#' @param standard_depths Numeric vector. Sorted, non-negative.
#' @param allocation `"uniform"` or `"presence"` (see `build_pelagic_stack()`).
#'
#' @returns A SpatRaster with `length(standard_depths)` layers, named
#'   `effort_<gear>_depth=<value>`. Cells outside a depth's per-cell band
#'   are NA.
#' @keywords internal
#' @noRd
build_benthic_stack <- function(layer, gear, buffer, bathymetry,
                                standard_depths, allocation) {
  if (is.na(buffer)) {
    stop("Gear '", gear, "' has mode='benthic' but benthic_buffer is NA.",
         call. = FALSE)
  }
  L <- terra::clamp(bathymetry - buffer, lower = 0)
  U <- bathymetry

  # Per-depth indicators stacked into one multi-layer SpatRaster. Both
  # comparisons must be raster-on-LHS — terra mishandles
  # `scalar <op> raster` when the raster value equals the scalar.
  ind_stack <- terra::rast(lapply(standard_depths, function(d) {
    (L <= d) & (U >= d)
  }))

  # Vectorised arithmetic across all depth layers at once: terra broadcasts
  # the single-layer `layer` over `ind_stack`, avoiding the per-depth
  # `lapply` + `Reduce(c, ...)` chain that previously allocated 57
  # intermediate rasters per gear.
  if (allocation == "uniform") {
    n_in_band <- sum(ind_stack)
    n_in_band_safe <- terra::ifel(n_in_band > 0, n_in_band, NA)
    out <- layer * ind_stack / n_in_band_safe
  } else {
    out <- layer * ind_stack
  }
  # Cells outside the per-depth band → NA (multiplication left them at 0).
  out <- terra::mask(out, ind_stack, maskvalues = 0)
  names(out) <- paste0("effort_", gear, "_depth=", standard_depths)
  out
}
