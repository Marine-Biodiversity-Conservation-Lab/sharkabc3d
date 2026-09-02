# Summarise across temporal dimension

Summarise multiple netCDF files across their temporal dimension while
preserving all non-temporal dimensions (for example longitude, latitude,
depth, or projected x/y dimensions).

## Usage

``` r
temporal_summarise(
  file_paths,
  fun = c("mean", "min", "max", "sd"),
  start_datetime = NULL,
  end_datetime = NULL,
  output_dir = NULL,
  filename = NULL,
  na.rm = TRUE,
  force = FALSE,
  quiet = FALSE
)
```

## Arguments

- file_paths:

  Character vector. Paths to one or more Copernicus netCDF (`.nc` or
  `.nc4`) files.

- fun:

  Character vector of temporal summary statistics. Supported values are
  `"mean"`, `"min"`, `"max"`, and `"sd"`.

- start_datetime:

  Optional start datetime used to filter the available netCDF time steps
  before summarising. A `Date`, `POSIXt`, or character value interpreted
  in UTC.

- end_datetime:

  Optional end datetime. Defaults to `start_datetime` when only a start
  is supplied. If both are `NULL`, all available time steps are
  summarised.

- output_dir:

  Optional character. Directory in which summarised netCDF files are
  written. Defaults to the directory containing the first input file.

- filename:

  Optional character. Output filename. When multiple statistics are
  requested, the statistic is appended before the extension (for example
  `summary_mean.nc`, `summary_max.nc`).

- na.rm:

  Logical. If `TRUE` (default), missing values are ignored within each
  grid cell/depth combination. If `FALSE`, any missing temporal value
  produces a missing summary value at that location.

- force:

  Logical. Overwrite existing summary files. Default `FALSE`.

- quiet:

  Logical. Suppress progress messages. Default `FALSE`.

## Value

Named character vector containing paths to the summarised netCDF files,
with names corresponding to `fun`.
