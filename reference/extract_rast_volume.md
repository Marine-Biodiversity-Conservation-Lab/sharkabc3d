# Extract raster values from a 3D volume

Crop a multi-depth SpatRaster to an area polygon and select depth layers
within a given depth range. Layer names must follow the
`{variable}_depth={value}` convention (native to WOA NetCDFs); the
numeric depth is parsed from each layer name. The nearest available
depth layers to `min_depth` and `max_depth` are used as the inclusive
bounds.

## Usage

``` r
extract_rast_volume(area, min_depth, max_depth, rast_3d)
```

## Arguments

- area:

  sf or SpatVector. Area polygon to crop the raster to.

- min_depth:

  Numeric. Shallowest depth (metres).

- max_depth:

  Numeric. Deepest depth (metres).

- rast_3d:

  SpatRaster. Multi-depth raster with `{variable}_depth={value}` layer
  names.

## Value

SpatRaster cropped to `area` and filtered to the depth range.
