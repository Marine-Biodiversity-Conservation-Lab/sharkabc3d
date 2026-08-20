# Load bathymetry raster

Load a GEBCO bathymetry raster from a NetCDF file using
[`terra::rast()`](https://rspatial.github.io/terra/reference/rast.html).
Validates that the file is NetCDF format, contains an `elevation`
variable, and has global extent (-180 to 180, -90 to 90). Values are
returned as-is (GEBCO uses negative values for below sea level).

## Usage

``` r
load_bathymetry(file_path)
```

## Arguments

- file_path:

  Character. Path to GEBCO bathymetry NetCDF file (e.g.,
  `"gebco_2025_sub_ice_topo/GEBCO_2025_sub_ice.nc"`).

## Value

SpatRaster with elevation values in metres.
