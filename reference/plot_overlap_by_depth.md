# Plot overlap by depth across fisheries

Horizontal bar chart showing per-depth-bin cell counts for the species
range, fishery footprint, and their intersection. For a single species
across multiple fisheries, this recreates the depth histogram panels
from Haque et al. (Figure 1).

## Usage

``` r
plot_overlap_by_depth(species_name, fishery_names, overlap_results)
```

## Arguments

- species_name:

  Character. Species name for the plot title.

- fishery_names:

  Character vector. Names of the sub-fisheries.

- overlap_results:

  Data frame or tibble with columns: species, fishery,
  volume_species_km3, volume_fishery_km3, volume_overlap_km3.

## Value

A ggplot object.
