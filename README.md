
<!-- README.md is generated from README.Rmd. Please edit that file -->

# sharkabc3d

<!-- badges: start -->

<!-- badges: end -->

**sharkabc3d** (Shark and Ray ABiotic Covariates in 3 Dimensions) is an
R package for three-dimensional marine spatial analysis of sharks, rays,
and chimaeras.

The three-dimensional marine environment poses a unique challenge for
spatial analyses. Most conventional GIS workflows represent space as a
two-dimensional plane, an abstraction that fails to capture the range of
depths and vertical overlap of marine habitat. Fisheries also operate at
different depths depending on gear type and target species, creating
depth-specific patterns of threat exposure that require analysis in 3D
volume rather than 2D planes to quantify. `sharkabc3d` provides
documented workflows and reusable functions for:

- extracting values from depth-stratified oceanographic rasters within
  user-defined geographic areas and depth windows;
- characterising the abiotic habitat (e.g., temperature, dissolved
  oxygen) of marine species using IUCN Red List ranges and World Ocean
  Atlas 2023 climatologies;
- calculating three-dimensional overlap between species distributions,
  fisheries effort, and other spatial layers;
- producing depth-aware maps and depth-profile plots of species ranges,
  environmental conditions, and cumulative fishing pressure.

## How it works

All 3D analyses use a stacked-raster approach built on `terra` and `sf`.
Polygons (species ranges, fishery footprints) are rasterized onto a
common bathymetry-aware grid where each cell stores presence plus the
shallowest and deepest depths the feature occupies (clamped to the
seafloor). Volume overlap between two rasterized ranges is then computed
per-cell via raster algebra. Multi-depth environmental rasters (e.g.,
WOA temperature at 57 standard depths) follow a
`{variable}_depth={value}` layer-naming convention so that downstream
functions can select the correct layers for a given depth window.

## Installation

You can install the development version of sharkabc3d from
[GitHub](https://github.com/) with:

``` r
# install.packages("devtools")
devtools::install_github("Marine-Biodiversity-Conservation-Lab/sharkabc3d")
```

Add an IUCN Red List API key to access species-assessment functions.
Sign up and acquire your API key at <https://api.iucnredlist.org/>:

``` r
usethis::edit_r_environ()
# Add the following line to the .Renviron file
# IUCN_API_KEY="your_iucn_api_key_here"
```

## Function overview

### Loading and preparing input data

- `load_bathymetry()` — load a GEBCO bathymetry NetCDF as a
  `SpatRaster`.
- `fetch_species_assessments()` — query the IUCN Red List API for
  taxonomy, Red List category, and depth limits, by SIS ID, scientific
  name, or comprehensive group code.
- `fill_missing_depths()` — fix swapped upper/lower depth values and
  fill missing values from genus-level means.

### Building the 3D study grid and rasterized ranges

- `create_study_raster()` — build an empty study-area `SpatRaster`
  covering the combined extent of one or more spatial inputs.
- `rasterize_range()` — rasterize a single species range or fishery
  footprint and assign per-cell `depth_min` / `depth_max` clamped to the
  seafloor.
- `rasterize_ranges()` — vectorised wrapper that rasterizes every row of
  an `sf` object with its own depth limits.

### 3D volume and overlap

- `calc_volume()` — total 3D volume (km³) of a rasterized range.
- `calc_volume_overlap()` — per-cell depth intervals and volumes for two
  rasterized ranges and their intersection (returns a 9-layer stack).
- `count_3d_overlap()` — binary `1`/`NA` raster indicating where two
  ranges overlap both horizontally and vertically; thin wrapper for
  richness / tally maps.

### Environmental extraction (3D)

- `extract_rast_range()` — mask a multi-depth environmental raster by a
  rasterized range, preserving each cell’s vertical refuge.
- `extract_rast_volume()` — crop a multi-depth raster to an area polygon
  and select layers within a depth range.
- `summarise_species_environment()` — summary statistics (min, max,
  mean, cell counts) per environmental variable inside a species’
  per-cell 3D range.

### World Ocean Atlas 2023 utilities

- `woa_download()` — download WOA 2023 NetCDF files (temperature,
  salinity, dissolved oxygen, oxygen saturation, AOU, nitrate,
  phosphate, silicate, density) at 0.25°, 1°, or 5° resolution, with
  caching.
- `woa_load_nc()` — load a WOA NetCDF and select a statistical field
  (e.g., objectively analyzed climatology), returning a `SpatRaster`
  with the package’s standard `{variable}_depth={value}` layer names.
- `woa_nc_extract()` — extract layers for a chosen statistical field
  from an already-loaded WOA `SpatRaster`.
- `woa_summarise_monthly()` — compute min, max, and max-minus-min across
  monthly WOA files at each depth layer.
- `woa_cache_dir()` / `woa_cache_clear()` — manage the persistent WOA
  download cache.

### Global Fishing Watch (fisheries effort)

- `gfw_effort_to_raster()` — turn the long-format apparent-fishing-hours
  tibble from `gfwr::gfw_ais_fishing_hours()` into a multi-layer
  `SpatRaster`, one layer per gear (or other grouping).
- `gfw_gear_depth_bands()` — combine a single-gear effort raster with
  bathymetry and a user-supplied gear-to-depth-band lookup to produce a
  depth-stratified effort stack (pelagic, benthic, midwater, or
  unknown).

### Plotting

- `plot_depth_profile()` — vertical depth profile (mean ± min–max
  ribbon) of an environmental variable within a species range.
- `plot_range_at_depth()` — map view of a species range with an
  environmental variable at a specific depth layer.
- `plot_volume_overlap()` — map view of per-cell 3D volume overlap
  between two ranges (e.g., species vs fishery).
- `plot_cumulative_pressure()` — map of cumulative fishing pressure on a
  species, coloured by the number of overlapping fisheries.
- `plot_overlap_by_depth()` — per-depth-bin bar chart of species,
  fishery, and overlap cell counts across multiple sub-fisheries.

## Acknowledgements

Thank you to the people that have inspired and collaborated on this work! 

Rachel Aitchison, Wade VanderWright, Amanda Arnold, Dr. Samm Sherman, Dr. Alifa Haque.

## Citation

Matsushiba, J. H., & Dulvy, N. K. *SharkABC3D: An R Package for
Three-Dimensional Marine Spatial Analyses of Abiotic Covariates.*
