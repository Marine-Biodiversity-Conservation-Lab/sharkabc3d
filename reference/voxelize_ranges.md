# Voxelize multiple ranges onto a study grid

Wrapper around
[`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
that processes multiple rows of an sf object, each with its own depth
limits. Displays a progress bar.

## Usage

``` r
voxelize_ranges(
  sf_data,
  voxel,
  bathymetry = NULL,
  depth_min_col,
  depth_max_col,
  name_col = NULL
)
```

## Arguments

- sf_data:

  sf object. Each row is a separate range to rasterize.

- voxel:

  The voxel grid that defines the study area. Either a `study_voxel`
  object (from
  [`create_study_voxel()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_voxel.md))
  or a plain SpatRaster template (e.g., from
  [`create_study_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_raster.md))
  whose cells become the horizontal footprint of each voxel column.

- bathymetry:

  SpatRaster. Seafloor depth raster (positive values in metres) matching
  `voxel`. Optional and ignored when `voxel` is a `study_voxel` (its
  seafloor is used).

- depth_min_col:

  Character. Column name in `sf_data` containing the minimum
  (shallowest) depth in metres.

- depth_max_col:

  Character. Column name in `sf_data` containing the maximum (deepest)
  depth in metres.

- name_col:

  Character. Optional column name to use for naming the output list.
  Default `NULL` (unnamed).

## Value

Named list of multi-layer SpatRasters (output of
[`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)).
