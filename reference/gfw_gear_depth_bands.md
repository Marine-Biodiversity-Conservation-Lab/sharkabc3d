# Build a depth-stratified fishing-effort stack for one gear class

Combine a single-gear effort raster (one layer, e.g. one slice of the
output of
[`gfw_effort_to_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/gfw_effort_to_raster.md))
with a bathymetry layer and a user-supplied gear → depth-band lookup to
produce a stack of rasters representing *where this gear's effort occurs
in the water column*.

## Usage

``` r
gfw_gear_depth_bands(
  effort_layer,
  gear,
  bathymetry,
  standard_depths,
  depth_lookup,
  allocation = "uniform",
  fallback = "drop"
)
```

## Arguments

- effort_layer:

  SpatRaster. Single-layer effort raster for one gear, e.g.
  `effort_by_gear[[paste0("effort_", gear)]]`.

- gear:

  Character. Gear class label. Used to look up the depth band in
  `depth_lookup` and to construct output layer names.

- bathymetry:

  SpatRaster. Positive-down seafloor depth (m), aligned to
  `effort_layer`.

- standard_depths:

  Numeric vector. Depth levels (m, positive down) at which the output
  stack is produced (e.g. WOA23 standard depths).

- depth_lookup:

  Data frame. User-supplied gear → depth-band mapping. No default is
  provided: operating depths vary by region, fleet, and time, and the
  appropriate values for any given analysis are the analyst's call.
  Required columns:

  - `geartype` — GFW gear class string (e.g. `"drifting_longlines"`).

  - `depth_min` — Shallowest operating depth (m, positive down). `NA`
    when `mode = "benthic"` or `"unknown"`.

  - `depth_max` — Deepest operating depth (m, positive down). `NA` when
    `mode = "benthic"` or `"unknown"`.

  - `mode` — One of `"pelagic"`, `"benthic"`, `"midwater"`, or
    `"unknown"`.

  - `benthic_buffer` — For `mode = "benthic"`, metres above the seafloor
    the gear is assumed to fish. `NA` otherwise.

  The single row whose `geartype` matches `gear` is selected.

- allocation:

  Character. `"uniform"` (split evenly across in-band depths, preserves
  total effort-hours) or `"presence"` (full value at every in-band depth
  — double-counts; use only for footprint maps). Default `"uniform"`.

- fallback:

  Character. Behaviour for `mode = "unknown"`: `"drop"` returns `NULL`
  (caller is expected to skip), `"surface"` treats the gear as 0-m
  surface effort. Default `"drop"`.

## Value

A SpatRaster with `length(standard_depths)` layers named
`effort_<gear>_depth=<value>`, or `NULL` when `mode = "unknown"` and
`fallback = "drop"`. A `depth_band` attribute (single-row data frame)
records the band actually used.

## Details

Processes one gear at a time so peak memory scales with a single gear's
depth-stratified stack rather than every gear at once. To build the full
multi-gear `effort_3d` stack, call this in a loop and combine (e.g.
`do.call(c, unname(list_of_stacks))`); writing intermediate results to
disk between iterations keeps a large analysis bounded — see the
vignette `gfw-fishing-effort-3d` for the standard pattern.

For the operating depth window:

- `mode = "pelagic"` — constant `[depth_min, depth_max]` from the
  lookup.

- `mode = "benthic"` — window is
  `[max(bathymetry - benthic_buffer, 0), bathymetry]` per cell, i.e. a
  thin band riding the seafloor.

- `mode = "midwater"` / `"unknown"` — handled per `fallback`.

The window is intersected with `standard_depths` to decide which depth
layers receive effort. Output layer names follow the package-standard
`effort_<gear>_depth=<value>` convention.
