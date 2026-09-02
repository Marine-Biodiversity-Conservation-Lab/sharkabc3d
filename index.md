# sharkabc3d

**sharkabc3d** (Shark and Ray Abiotic Covariates in 3 Dimensions) is an
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
# IUCN_REDLIST_KEY="your_iucn_api_key_here"
```

## Function overview

### Loading and preparing input data

- [`load_bathymetry()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/load_bathymetry.md)
  — load a GEBCO bathymetry NetCDF as a `SpatRaster`.
- [`fetch_species_assessments()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/fetch_species_assessments.md)
  — query the IUCN Red List API for taxonomy, Red List category, and
  depth limits, by SIS ID, scientific name, or comprehensive group code.
- [`fill_missing_depths()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/fill_missing_depths.md)
  — fix swapped upper/lower depth values and fill missing values from
  genus-level means.

### Building the 3D study grid and rasterized ranges

- [`create_study_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_raster.md)
  — build an empty study-area `SpatRaster` covering the combined extent
  of one or more spatial inputs.
- [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
  — rasterize a single species range or fishery footprint and assign
  per-cell `depth_min` / `depth_max` clamped to the seafloor.
- [`voxelize_ranges()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_ranges.md)
  — vectorised wrapper that rasterizes every row of an `sf` object with
  its own depth limits.

### 3D volume and overlap

- [`calc_volume()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/calc_volume.md)
  — total 3D volume (km³) of a rasterized range.
- [`calc_volume_overlap()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/calc_volume_overlap.md)
  — per-cell depth intervals and volumes for two rasterized ranges and
  their intersection (returns a 9-layer stack).
- [`count_3d_overlap()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/count_3d_overlap.md)
  — binary `1`/`NA` raster indicating where two ranges overlap both
  horizontally and vertically; thin wrapper for richness / tally maps.

### Environmental extraction (3D)

- [`extract_rast_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/extract_rast_range.md)
  — mask a multi-depth environmental raster by a rasterized range,
  preserving each cell’s vertical refuge.
- [`extract_rast_volume()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/extract_rast_volume.md)
  — crop a multi-depth raster to an area polygon and select layers
  within a depth range.
- [`summarise_species_environment()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/summarise_species_environment.md)
  — summary statistics (min, max, mean, cell counts) per environmental
  variable inside a species’ per-cell 3D range.

### World Ocean Atlas 2023 utilities

- [`woa_download()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_download.md)
  — download WOA 2023 NetCDF files (temperature, salinity, dissolved
  oxygen, oxygen saturation, AOU, nitrate, phosphate, silicate, density)
  at 0.25°, 1°, or 5° resolution, with caching.
- [`woa_load_nc()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_load_nc.md)
  — load a WOA NetCDF and select a statistical field (e.g., objectively
  analyzed climatology), returning a `SpatRaster` with the package’s
  standard `{variable}_depth={value}` layer names.
- `woa_nc_extract()` — extract layers for a chosen statistical field
  from an already-loaded WOA `SpatRaster`.
- `woa_summarise_monthly()` — compute min, max, and max-minus-min across
  monthly WOA files at each depth layer.
- [`woa_cache_dir()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_cache_dir.md)
  /
  [`woa_cache_clear()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_cache_clear.md)
  — manage the persistent WOA download cache.

### Global Fishing Watch (fisheries effort)

- [`gfw_effort_to_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/gfw_effort_to_raster.md)
  — turn the long-format apparent-fishing-hours tibble from
  [`gfwr::gfw_ais_fishing_hours()`](https://globalfishingwatch.github.io/gfwr/reference/gfw_ais_fishing_hours.html)
  into a multi-layer `SpatRaster`, one layer per gear (or other
  grouping).
- [`gfw_gear_depth_bands()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/gfw_gear_depth_bands.md)
  — combine a single-gear effort raster with bathymetry and a
  user-supplied gear-to-depth-band lookup to produce a depth-stratified
  effort stack (pelagic, benthic, midwater, or unknown).

## Contributing

Contributions are welcome. `sharkabc3d` is being actively built out from
a set of lab analyses into a general, tested package, and there is
plenty of well-scoped work available. Start with:

- **[CONTRIBUTING.md](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/CONTRIBUTING.md)**
  — development setup, data requirements, the branching/coordination
  workflow, and coding conventions.
- **[SPEC.md](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/SPEC.md)**
  — the roadmap; every planned function with its priority and source.
  Unchecked items are up for grabs.
- **[Code of
  Conduct](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/CODE_OF_CONDUCT.md)**.

New contributors: the “Known rough edges / good first issues” section of
`CONTRIBUTING.md` lists concrete starting points.

## Acknowledgements

Thank you to the people that have inspired and collaborated on this
work!

Rachel Aitchison, Wade VanderWright, Amanda Arnold, Dr. Samm Sherman,
Dr. Alifa Haque.

## Citation

Matsushiba, J. H., & Dulvy, N. K. *sharkabc3d: An R Package for
Three-Dimensional Marine Spatial Analyses of Abiotic Covariates.*
