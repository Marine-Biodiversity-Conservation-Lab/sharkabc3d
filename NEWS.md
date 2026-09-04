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
