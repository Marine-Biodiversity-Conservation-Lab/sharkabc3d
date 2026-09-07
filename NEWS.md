# sharkabc3d 0.1.1.9005

The 3D object model. `SpatVoxel` / `SpatEnvelope` replace the ad-hoc "3D
raster" conventions, and the volumetric functions now dispatch on them.

## New classes and constructors

* `SpatVoxel` (one layer per standard depth, cell value is the variable) and
  `SpatEnvelope` (exactly `depth_min`/`depth_max`, cell value is depth): S4
  classes extending `terra::SpatRaster` with their own validity rules.
  `SpatVolume` is a class union over the two and the dispatch target for
  volumetric operations, replacing the virtual `SpatDepthRaster`.
* `as_voxel()` / `as_envelope()` construct them. Prefer these over
  `methods::new()`: they normalise as well as validate, and are idempotent, so
  re-wrapping after a terra operation that drops the class is cheap.
  `as_voxel()` accepts a conforming multi-depth `SpatRaster`, a list of
  single-depth rasters, or a `SpatVoxel`, and sorts layers shallow to deep.
  `as_envelope()` attaches depth limits to a 2D footprint: each limit is a
  single number or a per-cell single-layer `SpatRaster`, or `x` already
  carries the two depth layers.
* `voxel_to_envelope()` / `envelope_to_voxel()` convert between the two, each
  taking a `fun` — an occupancy predicate one way (default `\(x) !is.na(x)`),
  a per-voxel profile the other. `voxel_to_envelope()` is lossy: an envelope
  is one continuous interval per cell, so interior gaps are filled.
* `vect_to_envelope()` builds an envelope from polygons. `depth_min` /
  `depth_max` are lists mixing numerics and rasters; per cell the deepest
  `depth_min` and shallowest `depth_max` win, so bathymetry is just another
  constraint. Constraint rasters must match the template's CRS, resolution and
  extent, and their NAs propagate rather than falling back to the remaining
  constraints.
* `depths()`, exported: the depths a voxel's layers stand for, parsed from
  `{variable}_depth={value}` layer names. It accepts a `SpatVoxel`, any
  conforming `SpatRaster`, or a bare character vector, so
  `depths(rownames(terra::global(v, "sum")))` works.
* Depths are positive metres increasing downward throughout the 3D model.
  Negative depths are an error, not silently flipped.

## New spatial query verbs

Each takes a `SpatEnvelope` or `SpatVoxel` paired with another 3D object, a 2D
`SpatRaster` footprint, or polygons (`SpatVector`, `sf`, `sfc`). A 2D object
restricts the domain horizontally and leaves its depths alone.

* `intersect_3d(x, y)` returns the 3D space the two share: an envelope with the
  shared depth interval, or a presence voxel. It is the one place that decides
  where two domains overlap; `calc_volume_overlap()` is now built on it, with
  unchanged numbers.
* `intersects_3d(x, y)` is the yes/no form: `TRUE` where both are present and
  their depths overlap, `FALSE` where both are present but disjoint or only one
  is, `NA` where neither is. terra's own three-way answer, made depth-aware.
* `mask()` gains depth-aware methods on terra's generic, so the article idiom
  `terra::mask(v, envelope_to_voxel(range, depths(v)))` becomes
  `mask(v, range)`. A voxel masked by an envelope puts the envelope on the
  voxel's depth levels first; a voxel masked by a voxel requires the same
  levels. Mismatched levels used to mask by layer position, silently; that is
  now an error.
* `terra::intersect()` on a `SpatEnvelope` or `SpatVoxel` is now an error
  naming `intersects_3d()` / `intersect_3d()`. terra's version is a 2D "both
  have data" test, and because terra keeps the subclass on its result, two
  envelopes 100 m apart came back as a `SpatEnvelope` of `TRUE` that passed
  validity.
* The verbs re-check tagged inputs and point to `as_voxel()` / `as_envelope()`,
  since terra keeps the class tag through operations that change the layer set
  (`[[`, `app()`).

## Breaking changes

| before | after |
| --- | --- |
| `calc_volume(r)` | `volume(as_envelope(r))` |
| `calc_volume_overlap(range_rast_a = a, range_rast_b = b)` | `calc_volume_overlap(x = a, y = b)` |
| `count_3d_overlap(a, b)` | `intersects_3d(a, b)` |
| `extract_rast_range(range, v)` | `mask(v, range)` |
| `extract_rast_volume(area, min_depth = 40, max_depth = 600, rast_3d = v)` | `extract_to_area(area, v, min_depth = 40, max_depth = 600)` |
| `voxelize_range(poly, voxel, depth_min = 0, depth_max = 500)` | `vect_to_envelope(poly, template, depth_min = 0, depth_max = list(500, seafloor))` |
| `create_study_voxel(template, bathymetry, depths)` | no replacement object — pass the three separately (the `study_voxel` class and its `print()` method go too) |
| `summarise_species_environment()` | `summarise_range()` in `vignette("woa-environmental-extraction")` |
| `voxel_to_envelope(fun = "extent" \| "threshold")` | `voxel_to_envelope(fun = <predicate>)` |

* `volume()` (was `calc_volume()`, matching how terra names `area()`) and
  `calc_volume_overlap()` are S4 generics on the 3D classes, so they accept a
  `SpatVoxel` as well as a `SpatEnvelope`, with formals `x` / `y`. The class is
  now the contract: a bare `SpatRaster` carrying `depth_min`/`depth_max` layers
  is rejected rather than duck-typed. A voxel's volume sums the slab each
  occupied level stands for, so interior gaps cost volume rather than being
  filled in; given one envelope and one voxel, the envelope is discretized onto
  the voxel's levels. Both now check that their inputs share a grid instead of
  reusing the first argument's cell areas for the second. Envelope volumes are
  numerically unchanged.
* `count_3d_overlap()` is retired for `intersects_3d()`, which returns
  `TRUE`/`FALSE`/`NA` instead of `1`/`NA`. `sum(stack, na.rm = TRUE)` over a
  stack of results still gives a richness map, now with a real `0` where a
  domain is present but nothing overlaps it.
* `extract_to_area()` (was `extract_rast_volume()`) takes the target first and
  the source second, as `extract_to_point()` does, and its depth bounds are
  optional and named. It requires and returns a `SpatVoxel`, accepts `sfc`
  areas alongside `sf` and `SpatVector`, and compares CRS with
  `terra::same.crs()` rather than string equality on WKT.
* `vect_to_envelope()` requires `polygon` and `template` to already share a
  CRS rather than projecting silently.
* `summarise_species_environment()` was analysis rather than package
  machinery. Its column contract (`{name}_min`, `_max`, `_mean`,
  `_n_surface_cells`, `_n_cells`, `_n_depths`) is unchanged in the vignette
  helper.
* `R/extract.R` is retired — it re-derived by hand what the classes now
  guarantee. `methods` moves into Imports.

## Bug fixes

* `mask(v, range)` also fixes a depth bug in `extract_rast_range()`, which
  tested exact point containment, so an envelope falling between two depth
  levels occupied none of them: `[10, 20]` against depths `c(0, 100, 200)` came
  back empty. `envelope_to_voxel()` tests slab overlap instead, so the same
  envelope now occupies the 0 m level, and its `bounds` argument chooses where
  the slab edges fall (`"top"` or the World Ocean Atlas `"midpoint"`).
* `calc_volume_overlap()` returned its nine-layer stack tagged `SpatEnvelope`.
  It is now the plain `SpatRaster` its documentation describes.

## Documentation and internals

* New article `vignette("woa-species-range-voxels")`: a species range polygon
  to a `SpatEnvelope`, applied to a WOA-shaped `SpatVoxel`, through to the
  overlapping voxel values and their summaries. Unlike the other articles it is
  fully synthetic and runs, so it doubles as a worked check of the idioms.
* Helpers shared by `R/volume.R` and the new `R/intersect.R` move to
  `R/utils-3d.R`. The constructors work on plain copies of their input, so a
  voxel layer can serve as a footprint without its class tag reaching the
  depth-aware `mask()` methods.

# sharkabc3d 0.1.1.9004

* `gfw_effort_to_raster()` can infer grid resolution and extent from the input
  data frame.

# sharkabc3d 0.1.1.9003

* Breaking: `load_bathymetry()` is renamed `load_gebco_bathymetry()` and moves
  from `R/load_data.R` to `R/gebco_bathymetry.R`. The new name makes the
  expected data source explicit; the function is otherwise unchanged.
* Runnable examples for `load_gebco_bathymetry()` — building a small stand-in
  NetCDF rather than requiring a multi-gigabyte GEBCO download (#37) — and for
  `fill_missing_depths()`, which moves to `R/iucn_utils.R` alongside the
  `fetch_species_assessments()` depth limits it repairs.

# sharkabc3d 0.1.1.9002

* `extract_to_point()` generalises point extraction from netCDF files, taking
  data frames, tibbles, `sf` POINT objects, matrices, named lists, and bare
  longitude/latitude/depth/date values or vectors. It preserves input structure
  where appropriate and transforms projected `sf` coordinates to
  longitude/latitude when possible.
* Runnable synthetic 2D and 3D netCDF examples for `extract_to_point()`,
  `extract2d()`, `extract3d_surface()`, `extract3d_bottom()`,
  `extract3d_nearest()` and `extract3d_all()`.

# sharkabc3d 0.1.1.9001

* Retire `R/plot.R`. The `plot_*()` functions were used by a single article and
  are no longer exported; `plot_depth_profile()` and `plot_range_at_depth()`
  now live inline in the WOA environmental extraction articles. `ggplot2` and
  `tidyterra` move from Imports to Suggests.

# sharkabc3d 0.1.1.9000

* Deprecate `woa_nc_extract()`, folding it into `woa_load_nc()`, its only
  caller. `woa_load_nc()` now checks for layer names that don't follow the
  package convention.

# sharkabc3d 0.1.1

* Add NetCDF extraction to observation points (#6, @davidruizgarci)
