# ---------------------------------------------------------------------------
# Global Fishing Watch (GFW) apparent fishing effort utilities.
#
# GFW publishes AIS-derived fishing effort (Kroodsma et al. 2018, Science)
# as CSVs of fishing hours per grid cell per day per flag state per gear
# type. These helpers take the raw CSV product, turn it into a SpatRaster
# stack indexed by flag / geartype, collapse the stack along user-chosen
# groupings, and build a depth-stratified effort layer by combining gear-
# class depth priors with bathymetry.
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
      "fixed_gear", "fishing"
    ),
    depth_min = c(0,  NA,  0,  NA,   0,   0,   0,   0,  NA,  NA,  NA),
    depth_max = c(400, NA, 140, NA,  20, 150, 200, 100, NA,  NA,  NA),
    mode = c(
      "pelagic", "benthic", "pelagic",
      "benthic", "pelagic", "pelagic",
      "pelagic", "pelagic", "benthic",
      "benthic", "unknown"
    ),
    benthic_buffer = c(NA, 50, NA, 50, NA, NA, NA, NA, 50, 50, NA),
    stringsAsFactors = FALSE
  )
}

#' Load GFW apparent fishing effort CSVs
#'
#' Read one or more Global Fishing Watch public fishing-effort CSVs
#' (available from
#' <https://globalfishingwatch.org/data-download/datasets/public-fishing-effort>)
#' into a single long-format data frame. Expected columns include a cell
#' centroid or lower-left lat/lon, a date field, `flag` (ISO3 flag state),
#' `geartype`, and an effort metric (typically `fishing_hours`).
#'
#' @param paths Character vector. Paths to one or more GFW effort CSV files
#'   (or a directory — all `.csv` files inside are read).
#' @param date_range Length-2 Date vector. Optional filter on the CSV's
#'   date field. Default `NULL` (no filter).
#' @param geartypes Character vector. Optional filter on `geartype`.
#'   Default `NULL` (keep all).
#' @param flags Character vector. Optional ISO3 filter on `flag`. Default
#'   `NULL` (keep all).
#' @param resolution Numeric. Grid resolution of the input CSV in degrees.
#'   GFW publishes 0.01 and 0.1 degree products. Default `0.01`.
#'
#' @returns A data frame with (at minimum) columns `lon`, `lat`, `date`,
#'   `flag`, `geartype`, `fishing_hours`. Grid resolution is attached as
#'   the `"resolution"` attribute.
#' @export
gfw_load_effort <- function(paths,
                            date_range = NULL,
                            geartypes = NULL,
                            flags = NULL,
                            resolution = 0.01) {
  stop("Not yet implemented")
}

#' Turn GFW effort records into a SpatRaster stack
#'
#' Rasterise a long-format GFW effort table onto a target grid, producing a
#' multi-layer SpatRaster where each layer corresponds to one combination of
#' the grouping variables (e.g. one layer per `flag × geartype`). Layer
#' names follow the package convention
#' `effort_<group1>=<level>_<group2>=<level>` so downstream `terra`
#' selection works with string patterns.
#'
#' @param effort Data frame returned by [gfw_load_effort()].
#' @param grid SpatRaster. Target grid (extent, resolution, CRS). The GFW
#'   CSV grid is rasterised onto this template.
#' @param group_by Character vector. One or more of `"geartype"`, `"flag"`
#'   (and any other categorical column in `effort`). One layer is produced
#'   per unique combination. Default `c("geartype", "flag")`.
#' @param value Character. Column in `effort` to aggregate (typically
#'   `"fishing_hours"`). Default `"fishing_hours"`.
#' @param fun Character or function. Aggregation applied to records that
#'   fall into the same cell × group. Default `"sum"`.
#'
#' @returns A SpatRaster with one layer per group combination. A
#'   `group_levels` attribute (data frame) records the mapping from layer
#'   index to group levels.
#' @export
gfw_effort_to_raster <- function(effort,
                                 grid,
                                 group_by = c("geartype", "flag"),
                                 value = "fishing_hours",
                                 fun = "sum") {
  stop("Not yet implemented")
}

#' Summarise a GFW effort raster stack along chosen groupings
#'
#' Collapse a flag × geartype (or similarly indexed) effort stack along a
#' user-selected subset of the grouping axes. For example, starting from a
#' stack indexed by both flag and geartype:
#' \itemize{
#'   \item `group_by = "geartype"` → one layer per geartype (summed across
#'     flags).
#'   \item `group_by = "flag"` → one layer per flag (summed across gears).
#'   \item `group_by = NULL` → a single-layer raster of total effort.
#' }
#'
#' Relies on the `group_levels` attribute set by [gfw_effort_to_raster()].
#'
#' @param effort_stack SpatRaster produced by [gfw_effort_to_raster()].
#' @param group_by Character vector. Subset of the grouping axes to retain.
#'   `NULL` collapses everything to a single total layer. Default `NULL`.
#' @param fun Character or function. Aggregation across layers within each
#'   retained group. Default `"sum"`.
#'
#' @returns A SpatRaster with one layer per retained group level (or one
#'   layer if `group_by = NULL`).
#' @export
gfw_summarise_raster <- function(effort_stack,
                                 group_by = NULL,
                                 fun = "sum") {
  stop("Not yet implemented")
}

#' Build a depth-stratified fishing-effort stack
#'
#' Combine a per-geartype effort raster (one layer per gear class, e.g.
#' from [gfw_summarise_raster()] with `group_by = "geartype"`) with a
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
#' the package-standard `effort_depth=<value>` naming so it can be combined
#' with WOA layers and [rasterize_range()] outputs by [calc_volume_overlap()]
#' et al.
#'
#' @param effort_by_gear SpatRaster. One layer per GFW gear class; layer
#'   names must match `depth_lookup$geartype`.
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
