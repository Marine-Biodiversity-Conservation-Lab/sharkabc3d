# Rasterise a GFW effort tibble onto a target grid

Turn the long-format apparent-fishing-hours tibble returned by
[`gfwr::gfw_ais_fishing_hours()`](https://globalfishingwatch.github.io/gfwr/reference/gfw_ais_fishing_hours.html)
(formerly
[`gfwr::get_raster()`](https://globalfishingwatch.github.io/gfwr/reference/gfw_renamed.html))
into a multi-layer SpatRaster on the package's canonical study grid.
Each level of `layer_by` becomes its own layer, named `effort_<level>`
(e.g. `effort_drifting_longlines`).

## Usage

``` r
gfw_effort_to_raster(
  effort,
  grid,
  layer_by = "geartype",
  value = "Apparent Fishing Hours",
  fun = "sum"
)
```

## Arguments

- effort:

  Data frame. Output of
  [`gfwr::gfw_ais_fishing_hours()`](https://globalfishingwatch.github.io/gfwr/reference/gfw_ais_fishing_hours.html)
  (a long-format tibble with at minimum `Lat`, `Lon`, a value, and a
  grouping column).

- grid:

  SpatRaster. Target grid (extent, resolution, CRS) — typically the same
  grid used for species ranges and WOA extraction.

- layer_by:

  Character. Column in `effort` whose levels become layers. `NULL`
  produces a single-layer total-effort raster. Default `"geartype"`.

- value:

  Character. Column in `effort` to aggregate. Default
  `"Apparent Fishing Hours"`.

- fun:

  Character or function. Aggregation applied to records that fall into
  the same cell × layer level. Default `"sum"`.

## Value

A SpatRaster with one layer per `layer_by` level (or one layer if
`layer_by = NULL`). Layer names follow `effort_<level>`.

## Details

The input is expected to carry a cell centroid (`Lat`, `Lon`), a value
column (default `"Apparent Fishing Hours"`), and one categorical column
matching the API's `group_by` — for example `geartype` or `flag` (note
lower-case; this is what `gfwr` actually returns). Records that fall
into the same target cell × layer level are aggregated with `fun`.
