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

## Examples

``` r
# Two features in different places: the grid has to cover both.
a <- terra::vect("POLYGON ((0 0, 2 0, 2 2, 0 2, 0 0))", crs = "EPSG:4326")
b <- terra::vect("POLYGON ((3 3, 5 3, 5 5, 3 5, 3 3))", crs = "EPSG:4326")

grid <- create_study_raster(list(a, b), res = 0.5)
terra::ext(grid)
#> SpatExtent : 0, 5, 0, 5 (xmin, xmax, ymin, ymax)
dim(grid)              # rows, columns, layers
#> [1] 10 10  1
terra::hasValues(grid) # FALSE: the grid is empty, it only defines geometry
#> [1] FALSE

# Inputs are projected to `crs` before their extents are combined, so a list
# mixing coordinate systems is fine.
create_study_raster(list(a, terra::project(b, "EPSG:3857")), res = 0.5)
#> class       : SpatRaster
#> size        : 10, 10, 1  (nrow, ncol, nlyr)
#> resolution  : 0.5, 0.5  (x, y)
#> extent      : 0, 5, 0, 5  (xmin, xmax, ymin, ymax)
#> coord. ref. : lon/lat WGS 84 (EPSG:4326)
```
