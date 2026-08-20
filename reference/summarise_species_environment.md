# Summarise environmental conditions within a species' 3D range

Takes a rasterized species range (output of
[`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
with per-cell `depth_min`/`depth_max` clamped to bathymetry) and a named
list of multi-depth environmental rasters. For each environmental
raster, values are restricted to cells + depths inside the species'
per-cell depth window via
[`extract_rast_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/extract_rast_range.md)
before summary statistics are computed. Apply across species with
[`lapply()`](https://rdrr.io/r/base/lapply.html) /
[`mapply()`](https://rdrr.io/r/base/mapply.html) in vignettes.

## Usage

``` r
summarise_species_environment(range_rast, raster_list)
```

## Arguments

- range_rast:

  SpatRaster. Output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
  with `depth_min` and `depth_max` layers.

- raster_list:

  Named list of multi-depth SpatRasters following the
  `{variable}_depth={value}` layer naming convention.

## Value

Single-row data frame of summary statistics across all rasters.

## Details

All rasters in `raster_list` must share extent, resolution, and CRS with
`range_rast`. Pre-align heterogeneous environmental rasters onto a
common grid before calling.

For each named raster, returns columns: `{name}_min`, `{name}_max`,
`{name}_mean`, `{name}_n_surface_cells`, `{name}_n_cells`,
`{name}_n_depths`.
