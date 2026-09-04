# Create a study voxel: the 3D voxel grid space for an analysis

Bundle the three things every 3D operation in the package needs into one
`study_voxel` object: a horizontal grid template, the seafloor depth on
that grid, and the standard depth levels that define the vertical
resolution of the voxel model. The supplied bathymetry is projected onto
the template and converted to a positive seafloor depth (land clamped to
0), so callers no longer prepare the seafloor by hand.
[`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
and
[`voxelize_ranges()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_ranges.md)
accept the returned object directly via their `voxel` argument.

## Usage

``` r
create_study_voxel(template, bathymetry, depths)
```

## Arguments

- template:

  SpatRaster. Empty raster defining the horizontal grid (extent,
  resolution, CRS) whose cells become the footprint of each voxel
  column, e.g. from
  [`create_study_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_raster.md).

- bathymetry:

  SpatRaster. GEBCO-style elevation raster with negative values below
  sea level (e.g. from
  [`load_gebco_bathymetry()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/load_gebco_bathymetry.md)).
  It is projected onto `template` and flipped to positive seafloor
  depth.

- depths:

  Numeric vector. Standard depth levels in metres (e.g. the World Ocean
  Atlas standard depths) that set the vertical resolution of the voxel
  model.

## Value

A `study_voxel` object: a list with `grid` (the empty horizontal
template), `seafloor` (positive seafloor depth on that grid), and
`depths` (sorted standard depth levels).
