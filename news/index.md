# Changelog

## sharkabc3d (development version)

## sharkabc3d 0.1.1

- Add NetCDF extraction to observation points
  ([\#6](https://github.com/Marine-Biodiversity-Conservation-Lab/sharkabc3d/issues/6),
  [@davidruizgarci](https://github.com/davidruizgarci))

## sharkabc3d 0.1.1.9000

- deprecate woa_nc_extract(), refactor to move functionality into
  woa_load_nc() since that is the only place woa_nc_extract() was used.
  addressed issue with test objects that had layer names that didn’t
  follow package convention that caused failed tests, added check in the
  woa_load_nc() function for this.

## sharkabc3d 0.1.1.9001

- Retire `R/plot.R`. The `plot_*()` functions were used by a single
  article and are no longer exported; `plot_depth_profile()` and
  `plot_range_at_depth()` now live inline in the WOA environmental
  extraction articles. `ggplot2` and `tidyterra` move from Imports to
  Suggests.
