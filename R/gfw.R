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
#     a depth-stratified stack using gear-class depth priors and
#     bathymetry, producing layers in the package-standard
#     `effort_<geartype>_depth=<value>` convention.
#   - `gfw_default_depth_lookup()` is the gear → depth-band table used by
#     `gfw_gear_depth_bands()`, compiled from the fisheries-gear
#     literature.
# ---------------------------------------------------------------------------

#' Default gear-class depth-band lookup
#'
#' Depth operating ranges for each Global Fishing Watch gear class, compiled
#' from the fisheries-gear literature (see `presentation/fishing-gear-depth-bands.md`).
#' Used as the default `depth_lookup` for [gfw_gear_depth_bands()].
#'
#' Columns:
#' \itemize{
#'   \item `geartype` — GFW gear class string (e.g. `"drifting_longlines"`).
#'   \item `depth_min` — Shallowest operating depth (m, positive down).
#'   \item `depth_max` — Deepest operating depth (m, positive down). May be
#'     `NA` when gear tracks the seafloor (see `mode`).
#'   \item `mode` — One of `"pelagic"` (fixed depth band in the water
#'     column), `"benthic"` (band clamped to bathymetry ± `benthic_buffer`),
#'     or `"midwater"` (variable, fixed band but audience should know it
#'     may track prey).
#'   \item `benthic_buffer` — For `mode = "benthic"`, metres above the
#'     seafloor the gear is assumed to fish. `NA` otherwise.
#' }
#'
#' @returns A data frame with one row per GFW gear class.
#' @export
gfw_default_depth_lookup <- function() {
  data.frame(
    geartype = c(
      "drifting_longlines", "set_longlines", "set_gillnets",
      "trawlers", "pole_and_line", "trollers",
      "purse_seines", "squid_jigger", "pots_and_traps",
      "fixed_gear", "fishing", "inconclusive"
    ),
    depth_min = c(0,  NA,  0,  NA,   0,   0,   0,   0,  NA,  NA,  NA, NA),
    depth_max = c(400, NA, 140, NA,  20, 150, 200, 100, NA,  NA,  NA, NA),
    mode = c(
      "pelagic", "benthic", "pelagic",
      "benthic", "pelagic", "pelagic",
      "pelagic", "pelagic", "benthic",
      "benthic", "unknown", "unknown"
    ),
    benthic_buffer = c(NA, 50, NA, 50, NA, NA, NA, NA, 50, 50, NA, NA),
    stringsAsFactors = FALSE
  )
}

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

#' Build a depth-stratified fishing-effort stack
#'
#' Combine a per-geartype effort raster (one layer per gear class, e.g.
#' from [gfw_effort_to_raster()] with `layer_by = "Geartype"`) with a
#' bathymetry layer and a gear → depth-band lookup to produce a stack of
#' rasters representing *where effort occurs in the water column*.
#'
#' For each gear type, the operating depth window is taken from
#' `depth_lookup`:
#' \itemize{
#'   \item `mode = "pelagic"` — constant `[depth_min, depth_max]` from the lookup.
#'   \item `mode = "benthic"` — window is `[max(bathymetry - benthic_buffer, 0),
#'     bathymetry]` per cell, i.e. a thin band riding the seafloor.
#'   \item `mode = "midwater"` / `"unknown"` — handled per `fallback`.
#' }
#'
#' The window is then intersected with `standard_depths` to decide which
#' depth layers the gear's effort should be allocated to. The output uses
#' the package-standard `effort_<geartype>_depth=<value>` naming so it can
#' be combined with WOA layers and [rasterize_range()] outputs by
#' [calc_volume_overlap()] et al.
#'
#' @param effort_by_gear SpatRaster. One layer per GFW gear class; layer
#'   names must match `depth_lookup$geartype` (with or without an
#'   `effort_` prefix from [gfw_effort_to_raster()]).
#' @param bathymetry SpatRaster. Positive-down seafloor depth (m), aligned
#'   to `effort_by_gear`.
#' @param standard_depths Numeric vector. Depth levels (m, positive down)
#'   at which the output stack is produced. Defaults to the WOA23 standard
#'   depths via [woa_standard_depths()] (not yet exported; pass explicitly
#'   for now).
#' @param depth_lookup Data frame. Gear → depth-band mapping. See
#'   [gfw_default_depth_lookup()] for the expected schema. Default uses
#'   that lookup.
#' @param allocation Character. How a gear's effort is distributed across
#'   the depth layers inside its band. One of:
#'   \itemize{
#'     \item `"uniform"` — split evenly across the depth layers the band
#'       intersects (preserves total effort-hours).
#'     \item `"presence"` — each intersecting layer gets the full value
#'       (effort-hours will be double-counted; use only for presence maps).
#'   }
#'   Default `"uniform"`.
#' @param fallback Character. Behaviour for gears with
#'   `mode = "unknown"`. One of `"drop"` (omit from the output) or
#'   `"surface"` (treat as 0-band surface effort). Default `"drop"`.
#'
#' @returns A SpatRaster stack of depth-stratified effort. Layer names
#'   follow the convention `effort_<geartype>_depth=<value>`. A
#'   `depth_bands` attribute (data frame) records the per-gear band used.
#' @export
gfw_gear_depth_bands <- function(effort_by_gear,
                                 bathymetry,
                                 standard_depths,
                                 depth_lookup = gfw_default_depth_lookup(),
                                 allocation = "uniform",
                                 fallback = "drop") {
  stop("Not yet implemented")
}
