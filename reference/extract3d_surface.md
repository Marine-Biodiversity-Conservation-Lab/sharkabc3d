# Extract the surface layer from a 3D netCDF variable

The surface layer is defined as the first available depth layer in the
netCDF file. This is usually the shallowest layer.

## Usage

``` r
extract3d_surface(data, nc, var = NULL, ...)
```

## Arguments

- data:

  Data frame containing observation points.

- nc:

  netCDF source. Can be a file path, vector of file paths, list of file
  paths, opened `ncdf4` object, list of opened objects, or a data frame
  with a file column.

- var:

  Name of the variable to extract from the netCDF file. If `NULL`, the
  function tries to detect the variable automatically from each file.
  This only works when each netCDF file contains one single variable.

- ...:

  Additional arguments passed to
  [`extract_netcdf()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/extract_netcdf.md).

## Value

The original `data` with extracted values appended.
