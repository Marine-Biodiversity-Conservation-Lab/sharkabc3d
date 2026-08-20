# Extract nearest, surface and bottom values from a 3D netCDF variable

For each observation, this function extracts the full vertical profile
at the nearest longitude, latitude and time cell. It then returns three
summary columns: nearest valid depth, surface and bottom.

## Usage

``` r
extract3d_all(data, nc, var = NULL, ...)
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

The original `data` with three extracted columns: `nearest_*`,
`surface_*` and `seabottom_*`.
