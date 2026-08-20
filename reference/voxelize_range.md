# Voxelize a species range or fishery footprint onto a study grid

Rasterize polygons onto a study grid and assign per-cell depth limits,
producing the voxel-model representation used throughout the package.
The maximum depth is clamped to the bathymetry (seafloor) so it never
exceeds the actual depth at each cell. Cells where the minimum depth is
deeper than the seafloor are set to NA (species not present).

## Usage

``` r
voxelize_range(polygons, voxel, bathymetry = NULL, depth_min, depth_max)
```

## Arguments

- polygons:

  sf or SpatVector. Species range or fishery footprint polygons.

- voxel:

  The voxel grid that defines the study area. Either a `study_voxel`
  object (from
  [`create_study_voxel()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_voxel.md)),
  which carries both the horizontal grid and the seafloor, or a plain
  SpatRaster template (e.g., from
  [`create_study_raster()`](https://marine-biodiversity-conservation-lab.github.io/sharkabc3d/reference/create_study_raster.md))
  whose cells become the horizontal footprint of each voxel column. This
  is the voxel model that the package builds all 3D operations on.

- bathymetry:

  SpatRaster. Seafloor depth raster with positive values in metres,
  matching the CRS and resolution of `voxel`. Pre-prepare from GEBCO
  with:
  `seafloor <- terra::clamp(-terra::project(bathy, voxel), lower = 0)`.
  Optional and ignored when `voxel` is a `study_voxel` (its seafloor is
  used).

- depth_min:

  Numeric. Minimum (shallowest) depth in metres.

- depth_max:

  Numeric. Maximum (deepest) depth in metres.

## Value

Multi-layer SpatRaster with layers: depth_min, depth_max. Cells where
the species/fishery is absent or the seafloor is shallower than
depth_min are NA.
