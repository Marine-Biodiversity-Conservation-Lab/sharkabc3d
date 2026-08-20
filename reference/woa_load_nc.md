# Load a WOA NetCDF file

Load a WOA .nc file and select layers for a given statistical field.
Returns a SpatRaster with layer names already following the
`{variable}_depth={value}` convention used throughout this package
(native to WOA NetCDFs).

## Usage

``` r
woa_load_nc(file_path, field = "an")
```

## Arguments

- file_path:

  Character. Path to a WOA .nc file.

- field:

  Character. Statistical field to select. One of: `"an"` (objectively
  analyzed climatology), `"mn"` (statistical mean), `"dd"` (number of
  observations), `"sd"` (standard deviation), `"se"` (standard error),
  `"oa"` (mean minus climatology), `"gp"` (number of mean values within
  radius of influence), `"sdo"` (objectively analyzed standard
  deviation), `"sea"` (standard error of the analysis). See the [WOA
  2023 Product
  Documentation](https://repository.library.noaa.gov/view/noaa/70581).

## Value

SpatRaster with standardized depth layer names.
