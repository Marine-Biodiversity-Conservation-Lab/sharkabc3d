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

## Examples

``` r
# Redirect the cache into a temporary directory so this example does not
# write to user filespace. In normal use you would skip this step and let
# the cache live in its platform-conventional location.
old <- Sys.getenv("R_USER_CACHE_DIR", unset = NA)
Sys.setenv(R_USER_CACHE_DIR = tempdir())

# The directory is created if it does not already exist
cache <- woa_cache_dir()
dir.exists(cache)
#> [1] TRUE

# This is where woa_download() writes when `output_dir` is not supplied
list.files(cache, pattern = "\\.nc$")
#> character(0)

if (is.na(old)) Sys.unsetenv("R_USER_CACHE_DIR") else
  Sys.setenv(R_USER_CACHE_DIR = old)
```
