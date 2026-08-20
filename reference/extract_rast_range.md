# Mask a 3D raster by a rasterized species range

Given a multi-depth environmental raster (`rast_3d`) and a rasterized
range (`range_rast`, the output of
[`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
with per-cell `depth_min` and `depth_max` layers clamped to bathymetry),
return a 3D raster where each cell retains the environmental value only
at depths inside that cell's `[depth_min, depth_max]` window. Cells
outside the range are NA across all depth layers.

## Usage

``` r
extract_rast_range(range_rast, rast_3d)
```

## Arguments

- range_rast:

  SpatRaster. Output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
  with layers `depth_min` and `depth_max` in metres.

- rast_3d:

  SpatRaster. Multi-depth raster with layer names following the
  `{variable}_depth={value}` convention.

## Value

SpatRaster with the same layers as `rast_3d`, masked to the per-cell
depth window of `range_rast`.

## Details

This preserves per-cell vertical refuge — e.g., a species whose maximum
depth is 1000 m but the seafloor is 400 m will only "see" the 0-400 m
layers at that cell. Used as the underlying extractor for species-range
depth profiles and range-aware environmental summaries.

`range_rast` and `rast_3d` must share extent, resolution, and CRS. The
caller is responsible for alignment (typically by rasterizing onto a
grid derived from `rast_3d`, or by pre-projecting with
`terra::project(range_rast, rast_3d[[1]], method = "near")`).
