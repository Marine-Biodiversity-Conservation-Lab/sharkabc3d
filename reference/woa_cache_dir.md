# WOA cache directory

Returns the path to the package's persistent cache directory for
downloaded WOA NetCDF files. Uses
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html) so the
location survives across sessions and follows platform conventions.

## Usage

``` r
woa_cache_dir()
```

## Value

Character. Path to cache directory (created if missing).
