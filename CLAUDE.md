# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**sharkabc3d** (Shark and Ray Abiotic Covariates in 3 Dimensions) — an R package for 3D marine spatial analysis of sharks, rays, and chimaeras. Enables depth-aware volume overlap calculations between species ranges, fisheries, and environmental rasters.

Goal: generalise the lab's previous 3D spatial analyses into a reusable, tested, documented R package.

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
1. Polygons (species ranges, fishery footprints) are rasterized onto a GEBCO bathymetry grid via `voxelize_range()`
2. Each cell stores presence + depth_min/depth_max (clamped to seafloor)
3. Volume overlap between two rasterized ranges is computed per-cell via raster algebra in `calc_volume_overlap()`
4. Environmental extraction uses multi-depth rasters (e.g., WOA temperature at 57 depth layers)

### Depth layer naming convention

All multi-depth SpatRasters **must** use `{variable}_depth={value}` layer names (e.g., `tan_depth=0`, `tan_depth=100`, `tan_depth=5500`). Functions like `extract_rast_volume()` parse these names to select layers within a depth range. Data source utilities are responsible for converting other formats into this convention.

### Function pipeline

```
fetch_species_assessments() → fill_missing_depths()
                                        ↓
load_bathymetry() + species polygons → voxelize_range() → calc_volume() / calc_volume_overlap()
                                        ↓
woa_load_nc() → extract_rast_volume() → summarise_species_environment()
```

### Where things are tracked

- `SPEC.md` — design rationale, conventions, and specs for **unbuilt** work. Not a status tracker; it has no per-function checkboxes. If a change departs from a spec or sets a new convention, record it under *Design decisions and deviations*.
- GitHub issues — what is in flight, who has it, and priority.
- `man/` + `NAMESPACE` — the authoritative list of what exists.

The core pipeline is built. Remaining planned work (all secondary priority): geometry utilities, `load_eez()`, species summary metrics, `plot_cross_section()`, Copernicus helpers, and retiring `woa_nc_extract()`.

### Key directories

- `R/` — Package functions (`extract.R`, `gfw.R`, `load_data.R`, `plot.R`, `volume.R`, `woa.R`). Stub functions use `stop("Not yet implemented")`
- `man/` — Roxygen2-generated documentation (auto-generated, do not edit manually)
- `tests/testthat/` — Test files mirroring `R/` (one file per source file)
- `renv/` — Reproducible environment lockfile managed by `renv`

### Coding conventions

- All exported functions use full roxygen2 documentation (`@param`, `@returns`, `@examples`, `@export`)
- `terra` is imported wholesale; `sf` and `stringr` are selectively imported
- Optional dependencies (e.g., `rredlist` for IUCN API) use `requireNamespace()` checks
- Vignettes use inline `sf::st_read()` with SQL filtering rather than wrapper functions for loading shapefiles
