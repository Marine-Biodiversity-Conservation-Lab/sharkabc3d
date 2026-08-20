# Plot cumulative fishing pressure on a species

Map showing cumulative fishing pressure from all sub-fisheries on a
given species. Each cell is coloured by the number of fisheries whose
depth range overlaps the species at that location. Reproduces the
per-species cumulative pressure maps from Haque et al.

## Usage

``` r
plot_cumulative_pressure(species_rast, fishery_rasters, species_name = NULL)
```

## Arguments

- species_rast:

  SpatRaster. Rasterized species range from
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md).

- fishery_rasters:

  List of SpatRasters. Rasterized fishery footprints from
  [`voxelize_range()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/voxelize_range.md).

- species_name:

  Character. Optional species name for the plot title.

## Value

A ggplot object.
