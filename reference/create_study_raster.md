# Create a study area raster grid

Build an empty raster covering the combined extent of one or more
spatial objects. Useful for defining the common grid before rasterizing
species ranges and fishery footprints.

## Usage

``` r
create_study_raster(layers, res = 0.01, crs = "EPSG:4326")
```

## Arguments

- layers:

  List of sf, sfc, SpatVector, or SpatRaster objects. The output extent
  will cover all objects.

- res:

  Numeric vector of length 1 or 2. Cell resolution in units of `crs`
  (degrees for lon/lat). Default `0.01` (~1 km at equator).

- crs:

  Character. Coordinate reference system. Default `"EPSG:4326"`.

## Value

An empty SpatRaster with the computed extent, resolution, and CRS.
