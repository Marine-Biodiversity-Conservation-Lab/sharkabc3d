# Project Spec

## Overview

This document describes the intended outcomes for the sharkABC3D (Shark and ray ABiotic Covariates in 3-Dimensions) project. SharkABC3D is an R package that is designed to facilitate the analysis of shark and ray habitat in 3D, enabling descriptions of habitat by depth and area. 

## Input data sources:
- bathymetry 
- species ranges from IUCN Red List (2.5D, with polygon areas with depth characteristics)
- species observations (3D, with points with X, Y, Z coordinates)
- species distribution models (continuous 2D rasters)
- satellite data (Copernicus, WOA datasets)
    - have depth and time layers 
- species traits (Sharkipedia, other literature)
- fishing pressure (gear type)
    - Global Fishing Watch (satellite imagery, 2D)
    - Fishing grounds (polygons with depth, 2.5D)

### IUCN Red List species ranges: 
- https://www.iucnredlist.org/resources/spatial-data-download 
- species ranges as polygons

### AquaMaps: 
- https://www.aquamaps.org/main/home_orig.php 
- https://www.biorxiv.org/content/10.1101/2025.10.19.683322v1.full.pdf 
- Species distribution models as 2D rasters 

## Previous projects to build upon: 
- 2.5D analysis with polygons with depth or depth range values 
- Species ranges intersecting with fisheries (Alifa Haque Bangladesh)
    - see `previous_projects/V1_Manuscript_ABH.docx`
    - 19 CR species × 7 artisanal sub-fisheries (gillnets, longlines, set-bag nets, prawn trawl)
    - hexagonal grid over Bangladesh EEZ (1km cells), mean bathymetric depth per cell from GEBCO
    - species presence/absence per cell from IUCN range polygons
    - fishery presence/absence per cell from participatory mapping (fisher interviews + KDE heatmaps)
    - depth overlap per cell: overlap of species depth range with gear depth range, constrained by bathymetry
    - 3D volume overlap = cell area × depth overlap, expressed as proportion of species total volume
    - key finding: horizontal overlap can be large but 3D overlap much smaller due to depth refuge
- Species ranges with depth value intersecting with WOA datasets, .nc files (Rachel's work)
    - WOA data is represented as a set of points at standard depths 
    - species ranges represented as 2D polygons with depth range (2.5D)
- Marine protected areas (Amanda's work)
    - not actually 3D analysis 
    - 2D intersection between species ranges and MPAs 
    - some MPAs have depth based restrictions, find example MPAs to represent this
- Deep sea sharks (see Brit's paper: https://www.science.org/doi/10.1126/science.ade9121)
    - vertical refuge

The idea is to create a R package that encapsulates the work across these papers, so that we can reproduce the work done and repeat depending on new data, params, etc. 

I had some grand ideas about creating a space-time cube model, combining raster and vector data. But this is probably overkill for now, point towards it as a future direction. Just refactor and implement the code used across the above 4 papers. 

## Definition of done:
- [x] Create empty functions with intended params
- [~] Create test data for each function (done for volume functions; pending for extract, plot, woa)
- [~] Implement tests to cover empty functions (done for `calc_volume`, `calc_volume_overlap`; pending for extract, plot, woa, load_data)
- [~] Implement each function, until tests pass (P1 volume + load_data done; P1 extract/woa/plot stubs remaining; P2 not started)
- [~] Write documentation for each function (all exported functions have roxygen2 docs)
- [~] Recreate past analyses with the package, document and use as vignettes for package
  - [~] 3D Bangladesh Fisheries (Alifa) — skeleton vignette created, eval=FALSE
  - [~] Dispersal Potential (Rachel) — skeleton vignette created, eval=FALSE
  - [~] Marine Protected Areas (Amanda) — skeleton vignette created, eval=FALSE
  - [ ] Deep sea sharks (Brit)
- [ ] Write package README.md
- [ ] Create documentation website with Quarto
- [ ] Create presentation for Sharks International 2026 using Quarto. Complete by May 1st before going to Sri Lanka.

## Depth layer convention

Multi-depth SpatRasters used by this package must encode depth in layer names using the format `{variable}_depth={value}` (e.g., `tan_depth=0`, `tan_depth=100`). This is the convention used by WOA NetCDF files natively. Data source utility functions (see Data source utilities section) are responsible for converting other formats into this convention. Functions like `extract_rast_volume()` parse layer names to determine which depth layers to select for a given depth range.

## Core functions:

**Priority for Sharks International 2026 (WIP, due May 1st):** Functions marked with **(P1)** have existing implementations in previous projects and are prioritized for the presentation. Functions marked **(P2)** are important but secondary. Functions in the Future directions section are post-conference.

### Data loading and preparation
Functions to load and standardize inputs into common formats used by the rest of the package.

- [x] ~~`load_species_ranges(source, ids)`~~ — Removed; replaced with inline `sf::st_read()` calls with SQL filtering in vignettes.
- [x] **(P1)** `fetch_species_assessments(api_key, sis_ids, species_names, group_code)` — Query IUCN Red List API for full species assessments including depth limits, taxonomy, Red List category. Returns data frame. (Originally spec'd as `fetch_species_depths`; expanded to full assessments.)
  - Source: `previous_projects/woa_extract_climate_3d/explore_woa_take_2.qmd`
- [x] **(P1)** `fill_missing_depths(upper, lower, genus, method = "genus_mean")` — Fill NA depth values using genus-level means. Handles swapped upper/lower values. Returns two-column tibble for use in `dplyr::mutate()`.
  - Source: `previous_projects/woa_extract_climate_3d/explore_woa_take_2.qmd`
- [x] **(P1)** `load_bathymetry(file_path)` — Load GEBCO bathymetry raster from NetCDF. Validates file format, variable name, and global extent. Returns SpatRaster.
- [ ] **(P2)** `load_eez(file_path)` — Load Exclusive Economic Zone polygons from geopackage. Returns sf with MRGID, GEONAME, geometry.
  - Source: `previous_projects/mpa.chondrichthyes-main/data-raw/scripts/eez.R`
- [ ] **(P2)** `load_mpa(source, ...)` — Load Marine Protected Area polygons from WDPA or MPAtlas. Filter by status (not Proposed), marine realm only. Returns sf with name, protection_level, geometry.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/wdpa_mpa_run_2025_07_22.R`

### Geometry utilities
Reusable spatial geometry operations used across species ranges, MPAs, and other polygon datasets.

- [ ] **(P2)** `fix_dateline_geometry(x)` — Fix sf geometries that cross the international date line. Creates thin polygon slice at -180/+180, applies st_difference, then st_wrap_dateline for remaining issues. Returns corrected sf.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/wdpa_mpa_run_2025_07_22.R` lines 58-99
- [ ] **(P2)** `validate_geometry(x)` — Check if sf geometry is non-empty and S2-valid. Optionally repair with st_make_valid + st_buffer(0). Returns logical or repaired sf.
  - Source: `previous_projects/mpa.chondrichthyes-main/R/mpa_valid_check.R`

### Volume calculation
Functions that compute 3D volumes using a stacked raster approach. The bathymetry raster serves as the common grid — species ranges and fishery footprints are rasterized onto it with `terra::rasterize()`, and depth overlap is computed via raster algebra. This avoids creating intermediate hex/vector grids and leverages terra's optimized operations. Approach developed for the Bangladesh fisheries analysis (Haque et al.) and generalized here.

- [x] `create_study_raster(layers, res, crs)` — Build an empty raster covering the combined extent of one or more spatial objects. Helper for defining the common grid before rasterizing. *(Not originally spec'd; added during implementation.)*
- [x] **(P1)** `rasterize_range(polygons, grid, bathymetry, depth_min, depth_max)` — Rasterize species range or fishery footprint onto a study grid. Returns two-layer SpatRaster (depth_min, depth_max) clamped to bathymetry; cells shallower than depth_min are NA.
  - Source: `previous_projects/V1_Manuscript_ABH.docx` Methods section
- [x] `rasterize_ranges(sf_data, grid, bathymetry, depth_min_col, depth_max_col, name_col)` — Batch wrapper around `rasterize_range()` with progress bar. *(Not originally spec'd; added during implementation.)*
- [x] **(P1)** `calc_volume(range_rast)` — Calculate total 3D volume of a rasterized range. Volume = sum of (cell_area × (depth_max - depth_min)) across all present cells. Returns numeric in km³.
- [x] **(P1)** `calc_volume_overlap(range_rast_a, range_rast_b)` — Calculate 3D volume overlap between two rasterized ranges. Returns 9-layer SpatRaster with per-cell depth limits and volumes for A, B, and their intersection.
  - Source: `previous_projects/V1_Manuscript_ABH.docx` Methods section — generalized from hex grid to raster algebra
- [x] `count_3d_overlap(range_rast_a, range_rast_b)` — Binary overlap raster (1 where two ranges overlap in 3D, NA elsewhere). Thin wrapper around `calc_volume_overlap()` for tally maps. *(Not originally spec'd; added during implementation.)*

### Environmental extraction
Generic functions that extract values from any multi-depth SpatRaster within a species' 3D range (area + depth). Raster-agnostic — works with any data source prepared by the functions in the Data source utilities section. Note: the Volume calculation section handles uniform-depth ranges (species range polygon + single min/max depth), while this section handles variable-depth environmental data (multi-layer rasters with values at standard depth levels, e.g., WOA temperature at 57 depth layers).

- [x] **(P1)** `extract_rast_volume(area, min_depth, max_depth, rast_3d)` — Crop a multi-depth SpatRaster to an area polygon and select depth layers within range (using the `{variable}_depth={value}` layer naming convention). Returns SpatRaster. (Generalized from existing `woa_volume_extract()`.)
  - Source: `R/woa_volume_extract.R`
- [x] **(P1)** `summarise_species_environment(species_range, min_depth, max_depth, raster_list)` — Takes one species range + depth + named list of multi-depth SpatRasters. Extracts and summarises each raster (min/max/mean + cell counts). Returns single-row data frame with `{name}_{stat}` columns per raster. Apply across species with `lapply()` in vignettes.
  - Source: `previous_projects/woa_extract_climate_3d/explore_woa_take_2.qmd` per-species loop body

### 2D area overlap analysis
Functions for spatial overlap analysis between species ranges and categorical zones (MPAs, EEZs, fishing grounds). Extracted from the MPA chondrichthyes project.

- [ ] **(P2)** `create_zone_hierarchy(zones_sf, level_col, level_order)` — From overlapping protection/category zones, sequentially erase higher-priority from lower-priority using terra::erase to produce non-overlapping polygons. Works with any number of levels (e.g., WDPA 4 levels: All > Part > None > Not Reported; MPAtlas 6 levels: full > high > light > minimal > incompatible > unknown).
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/wdpa_mpa_run_2025_07_22.R` lines 145-157 and `mpaatlas_mpa_run_2025_08_23.R` lines 124-191
- [ ] **(P2)** `calc_area_overlap(range_sf, zones_sf, level_col)` — Intersect a species range (or any polygon) with hierarchical non-overlapping zones. Compute area of intersection per level using spheroid-aware calculation. Returns tibble with level, area_m2, area_km2. Apply across species with `lapply()` in vignettes.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/00_wdpa_overlap_analysis.R` lines 248-276
- [ ] **(P2)** `summarise_area_overlap(overlap_results, group_cols, total_area_col)` — Pivot overlap results wider by level, compute proportions relative to total area (EEZ area or entire species range). Group by species, EEZ, or both.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/00_wdpa_overlap_analysis.R` lines 325-383

### Species summary metrics
Functions that aggregate environmental and trait data across species for comparative analysis.

- [ ] **(P2)** `calc_species_richness_by_depth(species_ranges, depth_table, depth_breaks)` — Count number of species present at each depth bin across a grid or region. Returns raster stack or tibble by depth.
  - Source: Finucci et al. 2024 Fig 4 concept
- [ ] **(P2)** `calc_trait_by_depth(species_ranges, depth_table, trait_table, trait_col, depth_breaks, fun = mean)` — Summarise a trait (e.g., caudal fin aspect ratio) by depth bin, weighted by species presence. Returns tibble.
- [ ] **(P2)** `calc_depth_restricted_range(species_range, depth_threshold, bathymetry)` — Calculate what portion of a species' 2D range overlaps with ocean deeper than a depth threshold. Masks species range polygon to areas where bathymetry exceeds threshold. Returns sf with restricted geometry + area.
  - Source: Finucci et al. 2024 Fig 5D concept — "range restricted by depth limit" vs "full range"

### Visualization
Functions to visualize 3D species-environment relationships.

- [x] **(P1)** `plot_depth_profile(species_name, rast_3d, min_depth, max_depth)` — Plot environmental variable (temp, DO) as a vertical depth profile within a species range. Line plot with depth on y-axis (inverted).
- [ ] **(P2)** `plot_cross_section(rast_3d, transect_line, depth_range)` — Plot a vertical cross-section of environmental data along a transect. Filled contour with lon/lat on x-axis, depth on y-axis.
- [x] **(P1)** `plot_range_at_depth(species_range, depth, rast_3d)` — Map view of a species range with environmental variable values at a specific depth layer.
- [x] **(P1)** `plot_volume_overlap(overlap_rast, name_a, name_b)` — Map view of per-cell 3D volume overlap between two rasterized ranges. Cells categorized as A only / B only / intersection with viridis palette matching Haque et al. Figure 1.
- [x] **(P1)** `plot_cumulative_pressure(species_rast, fishery_rasters, species_name)` — Map showing cumulative fishing pressure from all sub-fisheries on a given species. Cells colored by number of overlapping fisheries.
  - Source: `previous_projects/V1_Manuscript_ABH.docx` Figure 4
- [x] **(P1)** `plot_overlap_by_depth(species_name, fishery_names, overlap_results)` — Horizontal grouped bar chart comparing volume (km³) of species, fishery, and overlap across sub-fisheries. Reproduces Haque et al. depth histogram panels.
  - Source: `previous_projects/V1_Manuscript_ABH.docx` Figures 2 & 3

### Data source utilities
Helper functions to prepare specific data sources into the generic formats expected by the core functions above. Responsible for converting source-specific formats into the package's `{variable}_depth={value}` layer naming convention.

- [~] `woa_nc_extract(woa_nc, selected_field)` — Legacy function in `R/woa_volume_extract.R`. Selects layers for a given field from a WOA SpatRaster. To be superseded by `woa_load_nc()`. *(Pre-existing; not yet refactored.)*
- [~] `woa_volume_extract(area, min_depth, max_depth, woa_nc, selected_field)` — Legacy function in `R/woa_volume_extract.R`. Crops WOA raster to area and depth range. To be superseded by `extract_rast_volume()`. *(Pre-existing; not yet refactored.)*
- [x] **(P1)** `woa_load_nc(file_path, field = "an")` — Load a WOA .nc file and select layers for a given statistical field. Wrapper around `terra::rast()` + existing `woa_nc_extract()`. Returns SpatRaster with standardized depth layer names.
  - Source: `R/woa_volume_extract.R` `woa_nc_extract()`
- [x] **(P1)** `woa_summarise_monthly(monthly_dir, field = "an", files = NULL)` — Refactor of `data-raw/WOA.R`. Takes a directory of monthly WOA .nc files (or explicit `files` vector), computes min/max/diff across months at each depth. Returns named list of SpatRasters (min, max, diff). Works for any WOA variable.
  - Source: `data-raw/WOA.R`
- [x] **(P1)** `woa_download(variable, period, resolution, decade, output_dir, force, quiet)` — Download WOA23 NetCDFs from NCEI THREDDS with caching in `tools::R_user_dir()`. Skips re-download unless `force = TRUE`. *(Not originally spec'd; added during implementation to replace manual URL lookup.)*
- [x] `woa_cache_dir()`, `woa_cache_clear(confirm)` — Helpers to inspect/clear the cache directory used by `woa_download()`. *(Not originally spec'd; added during implementation.)*
- [ ] **(P2)** `copernicus_load(file_path)` — Load Copernicus marine data .nc file. Standardize depth layer naming to match package conventions. Returns SpatRaster.
- [ ] **(P2)** `copernicus_summarise(file_paths, fun)` — Summarise Copernicus data across time steps (e.g., monthly to annual min/max/mean). Returns named list of SpatRasters.
- [ ] **(P2)** `wdpa_prepare_hierarchy(wdpa_sf, eez_sf)` — WDPA-specific wrapper: separate by NO_TAKE levels (All > Part > None > Not Reported), apply dateline fixes, clip to individual EEZ, call `create_zone_hierarchy()`. Saves per-EEZ gpkg files.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/wdpa_mpa_run_2025_07_22.R` lines 114-338
- [ ] **(P2)** `mpaatlas_prepare_hierarchy(mpaatlas_sf, eez_sf)` — MPAtlas-specific wrapper: separate by 6 protection levels (full > high > light > minimal > incompatible > unknown), apply dateline fixes, clip to EEZ, call `create_zone_hierarchy()`.
  - Source: `previous_projects/mpa.chondrichthyes-main/analysis/mpaatlas_mpa_run_2025_08_23.R` lines 69-236

## Future directions (post Sharks International 2026):

### 3D species distribution modelling
Functions to create 3D species distribution models from point observations, combining horizontal (X, Y) occurrence data with vertical (Z) depth information. These extend traditional 2D SDMs into 3D by incorporating depth as an explicit dimension. Not grounded in existing project code — requires new R&D.

- [ ] `create_3d_sdm(occurrences, bathymetry, env_rasters, depth_breaks)` — Build a 3D species distribution model from point observations with depth (X, Y, Z). Fits a model (e.g., MaxEnt, GLM) at each depth layer using environmental covariates extracted at that depth. Returns a multi-layer SpatRaster of predicted habitat suitability by depth.
- [ ] `stack_2d_sdm_by_depth(sdm_raster, depth_table, bathymetry)` — Convert a traditional 2D SDM raster (e.g., from AquaMaps) into a 3D volume by extruding it through the species' depth range, constrained by bathymetry. Returns a rasterized range compatible with Volume calculation functions.
  - Source: Input data sources — AquaMaps continuous 2D rasters + IUCN depth ranges
- [ ] `predict_3d_habitat(model, env_rasters, depth_breaks, bathymetry)` — Generate 3D habitat suitability predictions from a fitted model. For each depth layer, extract environmental values and predict suitability. Mask cells where depth layer exceeds bathymetry. Returns multi-layer SpatRaster.
- [ ] `validate_3d_sdm(model, test_occurrences, depth_breaks)` — Evaluate 3D SDM performance using held-out occurrence data with depth. Computes metrics (AUC, TSS) both overall and per depth layer. Returns tibble of validation metrics.

### Space-time cube model
Combine raster and vector data into a unified space-time-depth data structure. Deferred as noted in the Overview — point towards as future direction after the core package is established.
