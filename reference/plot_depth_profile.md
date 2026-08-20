# Plot environmental depth profile for a species

Plot an environmental variable (e.g., temperature, dissolved oxygen) as
a vertical depth profile within the species range. At each depth layer
the spatial mean, min, and max are computed across cells where that
depth falls inside the species' per-cell depth window
(bathymetry-clamped). The mean is drawn as a line with points; the
min-max range is shaded as a ribbon. Depth is on the y-axis (inverted).

## Usage

``` r
plot_depth_profile(species_name, range_rast, rast_3d)
```

## Arguments

- species_name:

  Character. Species name used for the plot title.

- range_rast:

  SpatRaster. Output of
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md)
  with per-cell `depth_min` and `depth_max` layers.

- rast_3d:

  SpatRaster. Multi-depth environmental raster with layer names
  following the `{variable}_depth={value}` convention.

## Value

A ggplot object.

## Details

Uses
[`extract_rast_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/extract_rast_range.md)
to apply the per-cell depth window. Layers that end up all-NA (no cells
where the species is present at that depth) are dropped from the plot.
