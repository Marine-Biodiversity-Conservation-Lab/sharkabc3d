# sharkabc3d (development version)

# sharkabc3d 0.1.1
* Add NetCDF extraction to observation points (#6, @davidruizgarci)

# sharkabc3d 0.1.1.9000
* deprecate woa_nc_extract(), refactor to move functionality into woa_load_nc() since that is the only place woa_nc_extract() was used. addressed issue with test objects that had layer names that didn't follow package convention that caused failed tests, added check in the woa_load_nc() function for this.

# sharkabc3d 0.1.1.9001
* Retire `R/plot.R`. The `plot_*()` functions were used by a single article
  and are no longer exported; `plot_depth_profile()` and
  `plot_range_at_depth()` now live inline in the WOA environmental extraction
  articles. `ggplot2` and `tidyterra` move from Imports to Suggests.

# sharkabc3d 0.1.1.9002
* Generalizes point extraction from netCDF files through extract_to_point() and adds runnable examples for all exported point-extraction functions. The new interface supports data frames, tibbles, sf POINT objects, matrices, named lists, and direct longitude/latitude/depth/date values or vectors. It also preserves input structure where appropriate and transforms projected sf coordinates to longitude/latitude when possible.
* Runnable synthetic 2D and 3D netCDF examples are included for:
    `extract_to_point()`
    `extract2d()`
    `extract3d_surface()`
    `extract3d_bottom()`
    `extract3d_nearest()`
    `extract3d_all()`

# sharkabc3d 0.1.1.9003
* Rename `load_bathymetry()` to `load_gebco_bathymetry()` and move it from
  `R/load_data.R` to `R/gebco_bathymetry.R`. The new name makes the expected
  data source explicit; the function is otherwise unchanged. Callers must
  update to the new name.
* Add a runnable worked example to `load_gebco_bathymetry()`, which builds a
  small stand-in NetCDF rather than requiring a multi-gigabyte GEBCO
  download (#37).
* Add a runnable worked example to `fill_missing_depths()` and move it to
  `R/iucn_utils.R`, alongside `fetch_species_assessments()` whose depth limits
  it is designed to repair.
    
# sharkabc3d 0.1.1.9004
* Improve `gfw_effort_to_raster()` function to be able to assume grid resolution and extent from input dataframe. 

# sharkabc3d 0.1.1.9005
* Add the S4 classes underpinning the 3D object model. `SpatVoxel` (one layer
  per standard depth, depth as the layer index, cell values are the variable)
  and `SpatEnvelope` (exactly `depth_min`/`depth_max`, depth as the cell value,
  the object itself is the variable) each extend `terra::SpatRaster` directly
  and carry their own validity rules.
* `SpatVolume` is a class union over the two, replacing the earlier virtual
  `SpatDepthRaster` superclass. Both members determine a 3D domain over a 2D
  grid, so `SpatVolume` is the dispatch target for volumetric operations
  (volume, overlap, vertical extent); it asserts no shared structure, because
  the two store depth in dual roles.
* Implement `voxel_to_envelope()`. It takes a predicate `fun` applied to cell
  values; per cell, the shallowest depth where the predicate holds becomes
  `depth_min` and the deepest becomes `depth_max`. The default,
  `\(x) !is.na(x)`, gives the plain vertical extent of the data. The former
  `fun = c("extent", "threshold")` character interface is gone. The collapse is
  lossy: interior gaps in a voxel are filled, since an envelope stores a single
  continuous interval per cell.
* Implement `as_envelope()`, the constructor for `SpatEnvelope`. It attaches
  depth limits to a 2D footprint raster — any raster whose non-`NA` cells mark
  presence, such as a rasterized species range or a Global Fishing Watch effort
  layer — generalizing to rasters what `voxelize_range()` does for polygons.
  `depth_min` and `depth_max` are each either a constant or a per-cell
  single-layer raster; the optional `seafloor` clamps `depth_max` to the seabed
  and drops cells with no water column left below `depth_min`. A raster that
  already has `depth_min`/`depth_max` layers (e.g. `voxelize_range()` output) is
  promoted directly, so the function doubles as the coercion its name implies.
* `methods` moves into Imports (required by the S4 class definitions).

# sharkabc3d 0.1.1.9006
* Implement `as_voxel()`, the constructor for `SpatVoxel`. Prefer it over
  `methods::new("SpatVoxel", x)`: both validate, but only `as_voxel()`
  normalises the input first. It accepts a conforming multi-depth SpatRaster, a
  list of single-depth SpatRasters, or an existing `SpatVoxel`; builds layer
  names from a `depths` vector when given; and sorts layers shallow to deep
  rather than rejecting them, since that repair is unambiguous. Non-conforming
  layer names, negative depths, and duplicate depths are still errors — the
  sign in particular is not silently flipped, because that would change what
  the data mean.
* `as_voxel()` is idempotent, so re-wrapping after a terra operation that drops
  the class (`crop()`, `mask()`, `[[`) is cheap.
* Import `methods::is()`, used by `as_voxel()` and `voxel_to_envelope()`.

# sharkabc3d 0.1.1.9007
* Implement `envelope_to_voxel()`, the expansion from `SpatEnvelope` to
  `SpatVoxel`. It writes one layer per requested standard depth, marking a
  depth as occupied where it falls inside a cell's `[depth_min, depth_max]`
  interval, inclusive of both ends so that a voxel built on the depths
  `voxel_to_envelope()` reported round-trips to the same presence pattern.
* `fun` controls what the voxel carries. It receives the depths inside a cell's
  envelope and returns either one value per depth or a single value for all of
  them; the default writes `1` everywhere, giving a presence voxel. A profile
  function is what vertical-migration work needs — pass the share of time spent
  at each depth and the voxel carries that distribution instead. `fun` is
  evaluated once per distinct envelope interval on the grid rather than once
  per cell, since its result depends only on which depths are inside.
* Requested depths are sorted and deduplicated to match the voxel layer axis;
  negative depths are an error, following the package's positive-down
  convention. A cell whose envelope contains none of the requested depths comes
  back empty and is warned about, since that resolution loss is otherwise
  silent.
* `envelope_to_voxel()` is now exported.
