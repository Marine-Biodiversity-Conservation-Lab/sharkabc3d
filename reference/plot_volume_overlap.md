# Plot 3D volume overlap between two ranges

Map view of per-cell 3D volume overlap between two rasterized ranges.
Cells are categorised as range A only (species), intersection (overlap),
or range B only (fishery), matching the visualisation style of Haque et
al. Requires the output of
[`calc_volume_overlap()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/calc_volume_overlap.md).

## Usage

``` r
plot_volume_overlap(overlap_rast, name_a = "Species", name_b = "Fishery")
```

## Arguments

- overlap_rast:

  SpatRaster. Output of
  [`calc_volume_overlap()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/calc_volume_overlap.md),
  a multi-layer raster with layers: volume_a, volume_b, volume_overlap.

- name_a:

  Character. Label for range A (default `"Species"`).

- name_b:

  Character. Label for range B (default `"Fishery"`).

## Value

A ggplot object.
