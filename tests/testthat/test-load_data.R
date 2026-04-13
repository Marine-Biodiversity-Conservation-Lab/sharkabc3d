test_that("fill_missing_depths swaps reversed upper/lower values", {
  out <- fill_missing_depths(
    upper = c(100, 50),
    lower = c(10, 500),  # first row reversed
    genus = c("Carcharodon", "Sphyrna")
  )
  expect_equal(out$upper_depth, c(10, 50))
  expect_equal(out$lower_depth, c(100, 500))
})

test_that("fill_missing_depths fills NAs with genus means", {
  out <- fill_missing_depths(
    upper = c(0, 10, NA),
    lower = c(100, 200, NA),
    genus = c("Carcharhinus", "Carcharhinus", "Carcharhinus")
  )
  # Mean of non-NA values in the genus: upper = 5, lower = 150
  expect_equal(out$upper_depth[3], 5)
  expect_equal(out$lower_depth[3], 150)
})

test_that("fill_missing_depths leaves NA when entire genus is NA", {
  out <- fill_missing_depths(
    upper = c(NA, NA),
    lower = c(NA, NA),
    genus = c("Raja", "Raja")
  )
  expect_true(all(is.na(out$upper_depth)))
  expect_true(all(is.na(out$lower_depth)))
})

test_that("fill_missing_depths rejects unsupported methods", {
  expect_error(
    fill_missing_depths(1, 10, "Carcharodon", method = "zero"),
    "genus_mean"
  )
})

test_that("fill_missing_depths returns a tibble with expected columns", {
  out <- fill_missing_depths(
    upper = c(0, 10),
    lower = c(100, 200),
    genus = c("A", "B")
  )
  expect_s3_class(out, "tbl_df")
  expect_named(out, c("upper_depth", "lower_depth"))
  expect_equal(nrow(out), 2)
})

# ---------------------------------------------------------------------------
# load_bathymetry: exercise the validation paths. The happy-path test writes
# a minimal global NetCDF with terra::writeCDF, which may not be available
# in all environments.
# ---------------------------------------------------------------------------

test_that("load_bathymetry errors when file is missing", {
  expect_error(load_bathymetry("/no/such/file.nc"), "File not found")
})

test_that("load_bathymetry errors when file is not .nc", {
  tmp <- tempfile(fileext = ".tif")
  file.create(tmp)
  on.exit(unlink(tmp))
  expect_error(load_bathymetry(tmp), "NetCDF")
})

test_that("load_bathymetry happy path and extent validation", {
  tmp_good <- tempfile(fileext = ".nc")
  tmp_bad  <- tempfile(fileext = ".nc")
  on.exit(unlink(c(tmp_good, tmp_bad)))

  global <- terra::rast(nrows = 6, ncols = 12,
                        xmin = -180, xmax = 180,
                        ymin = -90, ymax = 90,
                        crs = "EPSG:4326")
  terra::values(global) <- seq_len(terra::ncell(global)) - 1000
  terra::varnames(global) <- "elevation"

  regional <- terra::rast(nrows = 4, ncols = 4,
                          xmin = 0, xmax = 10, ymin = 0, ymax = 10,
                          crs = "EPSG:4326")
  terra::values(regional) <- seq_len(terra::ncell(regional))
  terra::varnames(regional) <- "elevation"

  ok <- tryCatch({
    terra::writeCDF(global, tmp_good, overwrite = TRUE, varname = "elevation")
    terra::writeCDF(regional, tmp_bad, overwrite = TRUE, varname = "elevation")
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "terra::writeCDF unavailable")

  r <- load_bathymetry(tmp_good)
  expect_s4_class(r, "SpatRaster")

  expect_error(load_bathymetry(tmp_bad), "global extent")
})

# ---------------------------------------------------------------------------
# rasterize_range: core of the volume pipeline. Uses an in-memory grid and
# bathymetry; no disk I/O needed.
# ---------------------------------------------------------------------------

make_grid <- function() {
  # 5x5 grid covering a 5x5 degree box
  terra::rast(nrows = 5, ncols = 5,
              xmin = 0, xmax = 5, ymin = 0, ymax = 5,
              crs = "EPSG:4326")
}

make_bathy <- function(depth_val = 500) {
  r <- make_grid()
  terra::values(r) <- depth_val
  r
}

make_polygon <- function(xmin = 1, xmax = 4, ymin = 1, ymax = 4) {
  poly <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(xmin, ymin), c(xmax, ymin), c(xmax, ymax),
      c(xmin, ymax), c(xmin, ymin)
    ))),
    crs = "EPSG:4326"
  )
  sf::st_sf(geometry = poly)
}

test_that("rasterize_range returns depth_min and depth_max layers", {
  skip_if_not_installed("sf")
  out <- rasterize_range(
    polygons = make_polygon(),
    grid = make_grid(),
    bathymetry = make_bathy(500),
    depth_min = 0,
    depth_max = 200
  )
  expect_named(out, c("depth_min", "depth_max"))
  expect_s4_class(out, "SpatRaster")
})

test_that("rasterize_range assigns depth_min to cells inside polygon", {
  skip_if_not_installed("sf")
  out <- rasterize_range(
    polygons = make_polygon(),
    grid = make_grid(),
    bathymetry = make_bathy(500),
    depth_min = 10,
    depth_max = 200
  )
  vals <- terra::values(out[["depth_min"]])
  inside <- vals[!is.na(vals)]
  expect_true(all(inside == 10))
  expect_true(any(is.na(vals)))  # cells outside polygon
})

test_that("rasterize_range clamps depth_max to seafloor where shallower", {
  skip_if_not_installed("sf")
  # Bathymetry 100m everywhere; requested depth_max = 500m -> clamp to 100.
  out <- rasterize_range(
    polygons = make_polygon(),
    grid = make_grid(),
    bathymetry = make_bathy(100),
    depth_min = 0,
    depth_max = 500
  )
  vals <- terra::values(out[["depth_max"]])
  vals <- vals[!is.na(vals)]
  expect_true(all(vals == 100))
})

test_that("rasterize_range drops cells where seafloor is shallower than depth_min", {
  skip_if_not_installed("sf")
  # Bathymetry 50m; depth_min = 200m -> species cannot be present anywhere.
  out <- rasterize_range(
    polygons = make_polygon(),
    grid = make_grid(),
    bathymetry = make_bathy(50),
    depth_min = 200,
    depth_max = 500
  )
  expect_true(all(is.na(terra::values(out[["depth_min"]]))))
  expect_true(all(is.na(terra::values(out[["depth_max"]]))))
})

test_that("rasterize_range errors on mismatched bathymetry CRS", {
  skip_if_not_installed("sf")
  bad_bathy <- terra::rast(nrows = 5, ncols = 5,
                           xmin = 0, xmax = 5, ymin = 0, ymax = 5,
                           crs = "EPSG:3857")
  terra::values(bad_bathy) <- 500
  expect_error(
    rasterize_range(make_polygon(), make_grid(), bad_bathy, 0, 100),
    "CRS"
  )
})

test_that("rasterize_range errors on mismatched bathymetry resolution", {
  skip_if_not_installed("sf")
  bad_bathy <- terra::rast(nrows = 10, ncols = 10,
                           xmin = 0, xmax = 5, ymin = 0, ymax = 5,
                           crs = "EPSG:4326")
  terra::values(bad_bathy) <- 500
  expect_error(
    rasterize_range(make_polygon(), make_grid(), bad_bathy, 0, 100),
    "resolution"
  )
})

test_that("calc_volume of a rasterize_range output is positive and finite", {
  skip_if_not_installed("sf")
  out <- rasterize_range(
    polygons = make_polygon(),
    grid = make_grid(),
    bathymetry = make_bathy(500),
    depth_min = 0,
    depth_max = 200
  )
  v <- calc_volume(out)
  expect_true(is.finite(v))
  expect_gt(v, 0)
})
