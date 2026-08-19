# Project Spec

**What this document is.** The design rationale for sharkabc3d: what the package
is for, the conventions everything else depends on, the decisions taken along the
way, and the shape of the work that hasn't been built yet.

**What it is not.** A status tracker. Per-function progress is not recorded here,
because a hand-maintained checklist drifts from the code — it did, for most of
this project's history. Instead:

| To find out… | Look at… |
| --- | --- |
| What functions exist today and how to call them | The package reference — `man/`, `?sharkabc3d`, or the pkgdown site once it is up. `NAMESPACE` is authoritative. |
| What is being worked on, by whom | [GitHub issues](https://github.com/Marine-Biodiversity-Conservation-Lab/sharkabc3d/issues) |
| Why the package is built the way it is, and what is still planned | This document |

Items under [Planned work](#planned-work) are written to be pasted into an issue
more or less as-is. Open one before starting; see
[CONTRIBUTING.md](CONTRIBUTING.md).

## Overview

This document describes the intended outcomes for the sharkabc3d (Shark and Ray Abiotic Covariates in 3 Dimensions) project. sharkabc3d is an R package that is designed to facilitate the analysis of shark and ray habitat in 3D, enabling descriptions of habitat by depth and area. 

The idea is to create a R package that encapsulates the work across these papers, so that we can reproduce the work done and repeat depending on new data, params, etc. 

I had some grand ideas about creating a space-time cube model, combining raster and vector data. But this is probably overkill for now, point towards it as a future direction. Just refactor and implement the code used across the previous projects above. 

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
    - Haque et al. Bangladesh artisanal fisheries manuscript (unpublished; contact the maintainer)
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
- Deep sea sharks (see Brit's paper: https://www.science.org/doi/10.1126/science.ade9121)
    - vertical refuge

**Note on `Source:` pointers.** Where an item below names a source, it names the
prior analysis or manuscript the function is being generalised from, not a file
in this repository. That source material is not distributed here — if you are
picking up a planned item and need it, ask the maintainer.

---

## Project milestones

Coarse, slow-moving goals for the package as a whole. These are the only
checkboxes in this document; anything finer-grained belongs in an issue.

- [x] Establish the core function set — intended params, then implementations
- [x] Documentation for every exported function (roxygen2 → `man/`)
- [x] Test suite that runs with no external data, API keys, or network
- [x] Package README (generated from `README.Rmd`)
- [ ] Recreate past analyses as vignettes
  - [x] 3D Bangladesh Fisheries (Alifa) — `vignettes/bangladesh-fisheries-3d-overlap.Rmd`
  - [x] Dispersal Potential (Rachel) — `vignettes/woa-environmental-extraction.Rmd` plus `vignettes/woa-environmental-extraction-single-species.Rmd`
  - [x] Depth-stratified GFW fishing effort — `vignettes/gfw-fishing-effort-3d.Rmd`
  - [ ] Deep sea sharks (Brit)
- [ ] Vignettes runnable by someone other than the maintainer — all four are written end-to-end but set `eval = FALSE`, because they read large third-party datasets through hard-coded absolute paths
- [ ] Green CI — `.github/workflows/R-CMD-check.yaml` exists but is blocked on undeclared `vcr` and missing cassettes
- [ ] Documentation website (pkgdown or Quarto). This also supersedes any need to list existing functions here.

---

## Architecture and conventions

### Depth layer convention

Multi-depth SpatRasters used by this package must encode depth in layer names using the format `{variable}_depth={value}` (e.g., `tan_depth=0`, `tan_depth=100`). This is the convention used by WOA NetCDF files natively. Data source utilities are responsible for converting other formats into this convention. Functions like `extract_rast_volume()` parse layer names to determine which depth layers to select for a given depth range.

**Any new data-source utility must emit this naming convention.**

### Volume calculation: the stacked raster approach

3D volumes are computed on a stacked raster. The bathymetry raster serves as the common grid — species ranges and fishery footprints are rasterized onto it with `terra::rasterize()`, and depth overlap is computed via raster algebra. This avoids creating intermediate hex/vector grids and leverages terra's optimized operations.

Each rasterized range stores presence plus `depth_min`/`depth_max` per cell, clamped to the seafloor. Volume is the sum of `cell_area × (depth_max - depth_min)` over present cells; overlap between two ranges is the same arithmetic on the intersected depth window.

The approach was developed for the Bangladesh fisheries analysis (Haque et al.) on a hexagonal grid, and **generalized here from that hex grid to raster algebra**.

### Uniform-depth versus variable-depth data

Two different problems that are easy to confuse:

- **Uniform-depth ranges** — a species range polygon plus a single min/max depth. Handled by the volume functions, which extrude the polygon through one depth window (clamped per-cell to bathymetry).
- **Variable-depth environmental data** — multi-layer rasters holding values at standard depth levels (e.g. WOA temperature at 57 depths). Handled by the extraction functions, which are raster-agnostic and work on anything following the depth layer convention.

Extraction comes in two flavours, and the distinction matters: one takes an area polygon plus a single depth window, the other takes a *rasterized* range and honours each cell's own depth window — preserving per-cell vertical refuge rather than flattening it to one global window.

### Design decisions and deviations

Where the built package departs from what was first spec'd, and why. New deviations should be recorded here in the PR that introduces them.

- **`load_species_ranges()` was dropped.** Replaced by inline `sf::st_read()` calls with SQL filtering in the vignettes — a wrapper added indirection without hiding real complexity.
- **`fetch_species_depths()` became `fetch_species_assessments()`.** The IUCN API returns full assessments; narrowing the return value to depths alone threw away taxonomy and Red List category that callers then had to re-fetch.
- **A `study_voxel` object replaces hand-prepared inputs.** Every 3D operation needs the same three things — a horizontal grid template, positive-down seafloor depth on that grid, and the standard depth levels setting vertical resolution. Bundling them means callers no longer project and flip bathymetry by hand. Carries an S3 `print()` method.
- **Depth sign convention.** Depths are positive metres increasing downward, but GEBCO bathymetry is negative below sea level. The voxel constructor flips it and clamps land to 0. Document which convention any new argument uses.
- **WOA downloads are cached, not manual.** `woa_download()` fetches from NCEI THREDDS into `tools::R_user_dir()`, replacing manual URL lookup. Nothing writes outside that cache dir.
- **`woa_volume_extract()` was removed** in favour of the generic `extract_rast_volume()`. `woa_nc_extract()` survives as a legacy export — see Planned work.
- **GFW support was not originally spec'd.** Global Fishing Watch publishes a flat 2D effort product; turning it into a depth-stratified stack needs gear-class depth priors plus bathymetry (pelagic gear gets a fixed band, benthic gear a seafloor-riding band). Ingest is delegated to `gfwr`. Depth-banding runs one gear at a time to bound memory — loop and combine for a multi-gear stack.

---

## Planned work

Not yet built. Each entry gives an intended signature and behaviour; treat the signature as a starting proposal, not a contract — if implementation suggests better, say so in the issue and record the deviation above.

All remaining items are secondary priority: everything in the original **(high)** tier is built. Use issue labels for priority from here on, since priority changes and this file shouldn't have to.

### Data loading and preparation

- `load_eez(file_path)` — Load Exclusive Economic Zone polygons (Marine Regions World EEZ) from geopackage. Returns sf with MRGID, GEONAME, geometry. Used for study-area clipping; the Bangladesh vignette currently reads the EEZ inline.

### Geometry utilities

Reusable operations for cleaning polygon inputs — principally global IUCN species range polygons, which routinely cross the antimeridian and contain invalid rings.

- `fix_dateline_geometry(x)` — Fix sf geometries that cross the international date line. Creates thin polygon slice at -180/+180, applies st_difference, then st_wrap_dateline for remaining issues. Returns corrected sf.
- `validate_geometry(x)` — Check if sf geometry is non-empty and S2-valid. Optionally repair with st_make_valid + st_buffer(0). Returns logical or repaired sf.

### Species summary metrics

Aggregate environmental and trait data across species for comparative analysis.

- `calc_species_richness_by_depth(species_ranges, depth_table, depth_breaks)` — Count number of species present at each depth bin across a grid or region. Returns raster stack or tibble by depth.
  - Source: Finucci et al. 2024 Fig 4 concept
- `calc_trait_by_depth(species_ranges, depth_table, trait_table, trait_col, depth_breaks, fun = mean)` — Summarise a trait (e.g., caudal fin aspect ratio) by depth bin, weighted by species presence. Returns tibble.
- `calc_depth_restricted_range(species_range, depth_threshold, bathymetry)` — Calculate what portion of a species' 2D range overlaps with ocean deeper than a depth threshold. Masks species range polygon to areas where bathymetry exceeds threshold. Returns sf with restricted geometry + area.
  - Source: Finucci et al. 2024 Fig 5D concept — "range restricted by depth limit" vs "full range"

### Visualization

- `plot_cross_section(rast_3d, transect_line, depth_range)` — Plot a vertical cross-section of environmental data along a transect. Filled contour with lon/lat on x-axis, depth on y-axis.

### Data source utilities

- `copernicus_load(file_path)` — Load Copernicus marine data .nc file. Standardize depth layer naming to match the package convention. Returns SpatRaster.
- `copernicus_summarise(file_paths, fun)` — Summarise Copernicus data across time steps (e.g., monthly to annual min/max/mean). Returns named list of SpatRasters.

---

## Future directions

Not part of the core package. These come after the sections above are established, and are not grounded in existing project code.

### 3D species distribution modelling

Create 3D species distribution models from point observations, combining horizontal (X, Y) occurrence data with vertical (Z) depth information — extending traditional 2D SDMs by incorporating depth as an explicit dimension. Requires new R&D.

- `create_3d_sdm(occurrences, bathymetry, env_rasters, depth_breaks)` — Build a 3D species distribution model from point observations with depth (X, Y, Z). Fits a model (e.g., MaxEnt, GLM) at each depth layer using environmental covariates extracted at that depth. Returns a multi-layer SpatRaster of predicted habitat suitability by depth.
- `stack_2d_sdm_by_depth(sdm_raster, depth_table, bathymetry)` — Convert a traditional 2D SDM raster (e.g., from AquaMaps) into a 3D volume by extruding it through the species' depth range, constrained by bathymetry. Returns a rasterized range compatible with the volume functions.
  - Source: Input data sources — AquaMaps continuous 2D rasters + IUCN depth ranges
- `predict_3d_habitat(model, env_rasters, depth_breaks, bathymetry)` — Generate 3D habitat suitability predictions from a fitted model. For each depth layer, extract environmental values and predict suitability. Mask cells where depth layer exceeds bathymetry. Returns multi-layer SpatRaster.
- `validate_3d_sdm(model, test_occurrences, depth_breaks)` — Evaluate 3D SDM performance using held-out occurrence data with depth. Computes metrics (AUC, TSS) both overall and per depth layer. Returns tibble of validation metrics.

### Space-time cube model

Combine raster and vector data into a unified space-time-depth data structure. Deferred as noted in the Overview — point towards as future direction after the core package is established.
