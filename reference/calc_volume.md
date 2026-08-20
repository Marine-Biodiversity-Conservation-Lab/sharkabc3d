# Calculate total 3D volume of a rasterized range

Volume = sum of (cell_area x (depth_max - depth_min)) across all present
cells.

## Usage

``` r
calc_volume(range_rast)
```

## Arguments

- range_rast:

  SpatRaster. Output from
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md),
  with layers: depth_min, depth_max.

## Value

Numeric. Total volume in km³.
