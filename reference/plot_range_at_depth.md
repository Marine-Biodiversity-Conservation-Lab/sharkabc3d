# Plot species range at a specific depth layer

Map view of a species range with environmental variable values at a
specific depth layer.

## Usage

``` r
plot_range_at_depth(species_range, depth, rast_3d)
```

## Arguments

- species_range:

  sf or SpatVector. Species range polygon.

- depth:

  Numeric. Depth (metres) at which to display environmental data.

- rast_3d:

  SpatRaster. Multi-depth raster with layer names following the
  `{variable}_depth={value}` convention.

## Value

A ggplot object.
