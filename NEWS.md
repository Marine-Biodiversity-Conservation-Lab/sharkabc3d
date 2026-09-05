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
* Add the S4 classes for the 3D object model, both extending `terra::SpatRaster`
  with their own validity rules: `SpatVoxel` (one layer per standard depth, cell
  values are the variable) and `SpatEnvelope` (exactly `depth_min`/`depth_max`,
  depth as the cell value). `SpatVolume` is a class union over the two and the
  dispatch target for volumetric operations, replacing the virtual
  `SpatDepthRaster` superclass.
* Add `as_voxel()` and `as_envelope()`, the constructors for those classes.
  Prefer them over `methods::new()`: both validate, but only these normalise
  first, and both are idempotent, so re-wrapping after a terra operation that
  drops the class is cheap. `as_voxel()` accepts a conforming multi-depth
  SpatRaster, a list of single-depth rasters, or an existing `SpatVoxel`, and
  sorts layers shallow to deep. `as_envelope()` attaches depth limits to any 2D
  presence footprint, with an optional `seafloor` that clamps `depth_max` and
  drops cells with no water column below `depth_min`.
* Add `voxel_to_envelope()` and `envelope_to_voxel()`, the conversions between
  the two representations. `voxel_to_envelope()` takes a predicate `fun`
  (default `\(x) !is.na(x)`) and is lossy, since an envelope stores one
  continuous interval per cell and interior gaps are filled.
  `envelope_to_voxel()` takes a `fun` deciding what each voxel carries, writing
  presence by default; pass a profile function to carry a vertical-migration
  distribution instead.
* Depths are positive metres increasing downward throughout the 3D object model.
  Negative depths are an error in the class validity rules and in every
  constructor and conversion, rather than being silently flipped.
* Add `vect_to_envelope()`, which replaces `voxelize_range()` for polygons.
  Depth limits are `depth_min`/`depth_max` lists mixing numerics and rasters;
  per cell the deepest `depth_min` and shallowest `depth_max` win, so bathymetry
  is just another constraint rather than a dedicated argument. Constraint
  rasters must match the template's CRS, resolution, and extent, and their NAs
  propagate rather than falling back to the remaining constraints, so a cell
  with no bathymetry coverage gets no envelope.
* Breaking: the `fun = c("extent", "threshold")` character interface on
  `voxel_to_envelope()` is gone, replaced by the predicate above.
* `methods` moves into Imports, required by the S4 class definitions.
* Breaking: `voxelize_range()` and `create_study_voxel()` (with its
  `print.study_voxel()` method and the `study_voxel` class) are retired. Build
  the envelope directly instead, passing the seafloor as a `depth_max`
  constraint:

  ```r
  # before
  voxel <- create_study_voxel(template, bathymetry, depths)
  range_rast <- voxelize_range(sp_range, voxel, depth_min = 0, depth_max = 500)

  # after
  seafloor <- terra::clamp(terra::project(bathymetry, template) * -1, lower = 0)
  range_rast <- vect_to_envelope(sp_range, template,
                                 depth_min = 0,
                                 depth_max = list(500, seafloor))
  ```

  The `study_voxel` bundle has no replacement object: pass the grid template,
  the seafloor raster, and the standard depths as separate arguments.
  `vect_to_envelope()` requires `polygon` and `template` to already share a CRS
  rather than projecting silently, so project the polygons yourself first.
