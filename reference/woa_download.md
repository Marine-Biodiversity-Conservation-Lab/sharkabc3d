# Download a WOA NetCDF file (with caching)

Download World Ocean Atlas 2023 NetCDF files from the NCEI THREDDS
server. Files are cached in
[`woa_cache_dir()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_cache_dir.md)
(or a user-supplied `output_dir`) and skipped on subsequent calls unless
`force = TRUE`.

## Usage

``` r
woa_download(
  variable,
  period = "annual",
  resolution = "0.25",
  decade = NULL,
  output_dir = NULL,
  force = FALSE,
  quiet = FALSE
)
```

## Arguments

- variable:

  Character. One of `"temperature"`, `"salinity"`, `"dissolved_oxygen"`,
  `"oxygen_saturation"`, `"AOU"`, `"nitrate"`, `"phosphate"`,
  `"silicate"`, `"density"`.

- period:

  Character or numeric. `"annual"` (default), `"monthly"` (all 12
  months), `"seasonal"` (4 seasons), or a numeric vector where 0 =
  annual, 1:12 = monthly, 13:16 = seasonal.

- resolution:

  Character or numeric. `"0.25"` (default), `"1"`, or `"5"` degrees.

- decade:

  Character. Decade code (e.g. `"decav"`, `"all"`). Defaults to the
  canonical decade for the variable.

- output_dir:

  Character. Destination directory. Defaults to
  [`woa_cache_dir()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/woa_cache_dir.md).

- force:

  Logical. If `TRUE`, re-download even if the file exists. Default
  `FALSE`.

- quiet:

  Logical. Suppress download progress. Default `FALSE`.

## Value

Character vector of paths to downloaded .nc files.

## Details

On first use of the persistent cache in an interactive session, the
function prompts for consent to write to user filespace (per CRAN
Repository Policy). When the `curl` package is available, the estimated
size of each remote file is reported before downloading. A full set of
WOA files can be many gigabytes — supply `output_dir` to direct the
cache elsewhere (HPC scratch, external drive, etc.).
