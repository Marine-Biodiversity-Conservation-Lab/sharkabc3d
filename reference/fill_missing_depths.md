# Fill missing depth values

Fix swapped upper/lower depth values and fill NAs using genus-level
means. Designed for use inside
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html) —
returns a two-column tibble (`upper_depth` and `lower_depth`) that can
be unpacked with `mutate()`.

## Usage

``` r
fill_missing_depths(upper, lower, genus, method = "genus_mean")
```

## Arguments

- upper:

  Numeric vector. Upper (shallower) depth limit values, possibly with
  NAs or swapped values.

- lower:

  Numeric vector. Lower (deeper) depth limit values, possibly with NAs
  or swapped values.

- genus:

  Character vector. Genus names, used to compute genus-level mean depths
  for filling NAs.

- method:

  Character. Method for filling missing values. Currently only
  `"genus_mean"` is supported. Default `"genus_mean"`.

## Value

A tibble with columns `upper_depth` and `lower_depth`, suitable for use
with
[`dplyr::mutate()`](https://dplyr.tidyverse.org/reference/mutate.html).

## Examples

``` r
if (FALSE) { # \dontrun{
species_info <- species_info %>%
  mutate(fill_missing_depths(upper_depth_limit, lower_depth_limit, genus_name))
} # }
```
