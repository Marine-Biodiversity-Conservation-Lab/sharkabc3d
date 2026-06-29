# Helper: create a voxelize_range-like output (depth_min, depth_max layers)
make_range_rast <- function(depth_min_vals, depth_max_vals, ncol = 3, nrow = 3) {
  dmin <- terra::rast(nrows = nrow, ncols = ncol,
                      xmin = 0, xmax = ncol * 1000,
                      ymin = 0, ymax = nrow * 1000,
                      crs = "+proj=laea +lat_0=0 +lon_0=0 +datum=WGS84 +units=m")
  terra::values(dmin) <- depth_min_vals
  names(dmin) <- "depth_min"

  dmax <- terra::rast(dmin)
  terra::values(dmax) <- depth_max_vals
  names(dmax) <- "depth_max"

  c(dmin, dmax)
}

test_that("overlap volume never exceeds volume of either input range", {
  # Range A: covers all 9 cells, 0-100m depth
  a <- make_range_rast(
    depth_min_vals = rep(0, 9),
    depth_max_vals = rep(100, 9)
  )

  # Range B: covers only the center 3 cells, 50-200m depth
  b <- make_range_rast(
    depth_min_vals = c(NA, NA, NA, 50, 50, 50, NA, NA, NA),
    depth_max_vals = c(NA, NA, NA, 200, 200, 200, NA, NA, NA)
  )

  result <- calc_volume_overlap(a, b)
  vol_layers <- result[[c("volume_a", "volume_b", "volume_overlap")]]
  totals <- terra::global(vol_layers, "sum", na.rm = TRUE)$sum
  names(totals) <- c("volume_a", "volume_b", "volume_overlap")

  expect_true(totals[["volume_overlap"]] <= totals[["volume_a"]])
  expect_true(totals[["volume_overlap"]] <= totals[["volume_b"]])
  expect_true(totals[["volume_overlap"]] > 0)
})

test_that("overlap is zero when ranges don't spatially overlap", {
  # A: top 3 cells
  a <- make_range_rast(
    depth_min_vals = c(0, 0, 0, NA, NA, NA, NA, NA, NA),
    depth_max_vals = c(100, 100, 100, NA, NA, NA, NA, NA, NA)
  )

  # B: bottom 3 cells
  b <- make_range_rast(
    depth_min_vals = c(NA, NA, NA, NA, NA, NA, 0, 0, 0),
    depth_max_vals = c(NA, NA, NA, NA, NA, NA, 100, 100, 100)
  )

  result <- calc_volume_overlap(a, b)
  overlap_total <- terra::global(result[["volume_overlap"]], "sum", na.rm = TRUE)$sum

  # No spatial overlap: all overlap cells are NA, so sum is NA or 0
  expect_true(is.na(overlap_total) || overlap_total == 0)
})

test_that("overlap is zero when depth ranges don't overlap", {
  # Same cells, but A is 0-50m and B is 100-200m
  a <- make_range_rast(
    depth_min_vals = rep(0, 9),
    depth_max_vals = rep(50, 9)
  )

  b <- make_range_rast(
    depth_min_vals = rep(100, 9),
    depth_max_vals = rep(200, 9)
  )

  result <- calc_volume_overlap(a, b)
  overlap_total <- terra::global(result[["volume_overlap"]], "sum", na.rm = TRUE)$sum

  expect_equal(overlap_total, 0)
})

test_that("full overlap when ranges are identical", {
  a <- make_range_rast(
    depth_min_vals = rep(0, 9),
    depth_max_vals = rep(100, 9)
  )

  result <- calc_volume_overlap(a, a)
  vol_layers <- result[[c("volume_a", "volume_b", "volume_overlap")]]
  totals <- terra::global(vol_layers, "sum", na.rm = TRUE)$sum
  names(totals) <- c("volume_a", "volume_b", "volume_overlap")

  expect_equal(totals[["volume_overlap"]], totals[["volume_a"]])
  expect_equal(totals[["volume_overlap"]], totals[["volume_b"]])
})

# Helpers for study_voxel tests: a lon/lat template grid, a GEBCO-style
# elevation raster (negative below sea level), and a polygon inside the grid.
sv_template <- function() {
  terra::rast(nrows = 5, ncols = 5,
              xmin = 0, xmax = 5, ymin = 0, ymax = 5, crs = "EPSG:4326")
}
sv_elevation <- function(elev = -500) {
  r <- sv_template()
  terra::values(r) <- elev
  r
}
sv_polygon <- function() {
  poly <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
    ))),
    crs = "EPSG:4326"
  )
  sf::st_sf(geometry = poly)
}

test_that("create_study_voxel bundles grid, positive seafloor, and sorted depths", {
  sv <- create_study_voxel(
    template = sv_template(),
    bathymetry = sv_elevation(-500),
    depths = c(100, 0, 50)
  )
  expect_s3_class(sv, "study_voxel")
  expect_named(sv, c("grid", "seafloor", "depths"))
  expect_equal(sv$depths, c(0, 50, 100))
  # Elevation -500 becomes positive seafloor depth 500.
  vals <- terra::values(sv$seafloor)
  expect_true(all(vals == 500, na.rm = TRUE))
})

test_that("create_study_voxel clamps land (positive elevation) to zero depth", {
  sv <- create_study_voxel(sv_template(), sv_elevation(120), depths = c(0, 100))
  vals <- terra::values(sv$seafloor)
  expect_true(all(vals == 0, na.rm = TRUE))
})

test_that("create_study_voxel validates its inputs", {
  expect_error(create_study_voxel("nope", sv_elevation(), 1), "template")
  expect_error(create_study_voxel(sv_template(), "nope", 1), "bathymetry")
  expect_error(create_study_voxel(sv_template(), sv_elevation(), "nope"), "depths")
})

test_that("voxelize_range accepts a study_voxel and derives the seafloor", {
  skip_if_not_installed("sf")
  sv <- create_study_voxel(sv_template(), sv_elevation(-500), depths = c(0, 100))
  out <- voxelize_range(
    polygons = sv_polygon(), voxel = sv,
    depth_min = 0, depth_max = 200
  )
  expect_named(out, c("depth_min", "depth_max"))
  # Seafloor at 500 m, requested max 200 m -> not clamped, present cells = 200.
  vals <- terra::values(out[["depth_max"]])
  expect_true(all(vals[!is.na(vals)] == 200))
})

test_that("voxelize_range errors when voxel is a SpatRaster and bathymetry is missing", {
  skip_if_not_installed("sf")
  expect_error(
    voxelize_range(sv_polygon(), sv_template(), depth_min = 0, depth_max = 100),
    "bathymetry"
  )
})

test_that("calc_volume returns correct value for uniform grid", {
  # 9 cells, each 1km x 1km, 100m depth = 9 * 1 * 0.1 = 0.9 km³
  r <- make_range_rast(
    depth_min_vals = rep(0, 9),
    depth_max_vals = rep(100, 9)
  )

  vol <- calc_volume(r)

  # Cell area depends on projection; just check it's positive and reasonable
  expect_true(vol > 0)
  # With 1km cells: 9 cells * 1 km² * 0.1 km depth = 0.9 km³
  expect_equal(vol, 0.9, tolerance = 0.01)
})
