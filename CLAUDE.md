# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**sharkabc3d** (Shark and Ray Abiotic Covariates in 3 Dimensions) — an R package for 3D marine spatial analysis of sharks, rays, and chimaeras. Enables depth-aware volume overlap calculations between species ranges, fisheries, MPAs, and environmental rasters.

Target: presentation at Sharks International 2026 (May 1st deadline).

## R Version

Use R 4.4.3.

## Build and Test Commands

```bash
# Check package (runs R CMD check with tests, examples, vignettes)
R CMD check .

# Build package
R CMD build .

# Install locally
R CMD INSTALL .

# Run all tests (testthat edition 3)
Rscript -e 'testthat::test_local()'

# Run a single test file
Rscript -e 'testthat::test_file("tests/testthat/test-example.R")'

# Regenerate documentation from roxygen2 comments
Rscript -e 'roxygen2::roxygenise()'

# Build vignettes
Rscript -e 'devtools::build_vignettes()'
```

## Architecture

### Core spatial approach

All 3D analysis uses a **stacked raster** approach built on `terra` and `sf`:
1. Polygons (species ranges, fishery footprints) are rasterized onto a GEBCO bathymetry grid via `rasterize_range()`
2. Each cell stores presence + depth_min/depth_max (clamped to seafloor)
3. Volume overlap between two rasterized ranges is computed per-cell via raster algebra in `calc_volume_overlap()`
4. Environmental extraction uses multi-depth rasters (e.g., WOA temperature at 57 depth layers)

### Depth layer naming convention

All multi-depth SpatRasters **must** use `{variable}_depth={value}` layer names (e.g., `tan_depth=0`, `tan_depth=100`, `tan_depth=5500`). Functions like `extract_rast_volume()` parse these names to select layers within a depth range. Data source utilities are responsible for converting other formats into this convention.

### Function pipeline

```
fetch_species_assessments() → fill_missing_depths()
                                        ↓
load_bathymetry() + species polygons → rasterize_range() → calc_volume() / calc_volume_overlap()
                                        ↓
woa_load_nc() → extract_rast_volume() → summarise_species_environment()
```

### Priority tiers (see SPEC.md for full details)

- **P1**: Volume calculation pipeline, environmental extraction, WOA utilities, visualization — needed for Sharks International
- **P2**: 2D area overlap (MPA analysis), geometry utilities, data source helpers (Copernicus, WDPA, MPAtlas)

### Key directories

- `R/` — Package functions. Stub functions use `stop("Not yet implemented")`
- `data-raw/` — Raw data files (WOA NetCDFs, Bangladesh study data, processing scripts). Excluded from package build
- `data-processed/` — Pre-computed rasters (WOA min/max/diff across months)
- `previous_projects/` — Reference implementations being refactored into this package
- `vignettes/` — Three analysis vignettes reproducing past papers (Bangladesh fisheries 3D, MPA overlap, WOA extraction)

### Coding conventions

- All exported functions use full roxygen2 documentation (`@param`, `@returns`, `@examples`, `@export`)
- `terra` is imported wholesale; `sf` and `stringr` are selectively imported
- Optional dependencies (e.g., `rredlist` for IUCN API) use `requireNamespace()` checks
- Vignettes use inline `sf::st_read()` with SQL filtering rather than wrapper functions for loading shapefiles
