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