# Summarise monthly WOA data across months

Takes a directory of monthly WOA .nc files (e.g., 12 files for January
to December) and computes the min, max, and max-minus-min (diff) across
months at each depth layer. Works for any WOA variable.

## Usage

``` r
woa_summarise_monthly(monthly_dir = NULL, field = "an", files = NULL)
```

## Arguments

- monthly_dir:

  Character. Path to directory containing monthly WOA .nc files. All
  `.nc` files in the directory are loaded.

- field:

  Character. Statistical field to select from each file. Default `"an"`.

- files:

  Character vector. Optional explicit list of files (overrides
  `monthly_dir`).

## Value

Named list of SpatRasters: `min`, `max`, `diff`. Each uses the
`{variable}_depth={value}` layer naming convention.

## Details

Replaces the ad-hoc loop in `data-raw/WOA.R`.
