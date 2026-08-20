# Binary 3D overlap between two rasterized ranges

Returns a single-layer raster that is `1` in cells where the two ranges
overlap both horizontally (both present) and vertically (their depth
intervals intersect), and `NA` otherwise. Thin wrapper around
[`calc_volume_overlap()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/calc_volume_overlap.md)
for richness / tally maps where the per-cell overlap volume is not
needed.

## Usage

``` r
count_3d_overlap(range_rast_a, range_rast_b)
```

## Arguments

- range_rast_a:

  SpatRaster. First rasterized range (output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)).

- range_rast_b:

  SpatRaster. Second rasterized range (output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)).

## Value

Single-layer SpatRaster (`1` where the two ranges overlap in 3D, `NA`
elsewhere).
