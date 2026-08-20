# Calculate 3D volume overlap between two rasterized ranges

Computes per-cell depth intervals and volumes for two ranges and their
intersection. Returns a 9-layer raster stack containing the depth limits
for each range and their overlap, plus the corresponding volumes. Cells
where a range is absent have NA for that range's layers. The
intersection layers are NA where the two depth intervals do not overlap.

## Usage

``` r
calc_volume_overlap(range_rast_a, range_rast_b)
```

## Arguments

- range_rast_a:

  SpatRaster. First rasterized range (output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)).

- range_rast_b:

  SpatRaster. Second rasterized range (output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)).

## Value

Multi-layer SpatRaster with 9 layers:

- depth_min_a, depth_max_a:

  Depth limits of range A (m)

- depth_min_b, depth_max_b:

  Depth limits of range B (m)

- depth_min_overlap, depth_max_overlap:

  Depth limits of the intersection (m). NA where ranges do not overlap
  in depth.

- volume_a, volume_b:

  Per-cell volume of each range (km³)

- volume_overlap:

  Per-cell overlap volume (km³)
