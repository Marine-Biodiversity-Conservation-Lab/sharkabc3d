# Helper: 2x2 voxel over four standard depths, cell 1 has an interior gap
make_voxel_rast <- function(depths = c(0, 100, 200, 300),
                            vals = list(c(10, NA,  5, NA),
                                        c(NA, 20,  6, NA),
                                        c(12, 21,  7, NA),
                                        c(NA, NA,  8, NA)),
                            varname = "temp") {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  lays <- lapply(vals, function(v) terra::setValues(r, v))
  out <- terra::rast(lays)
  names(out) <- paste0(varname, "_depth=", depths)
  out
}

test_that("SpatVoxel and SpatEnvelope are SpatRasters and SpatVolumes", {
  v <- methods::new("SpatVoxel", make_voxel_rast())

  expect_s4_class(v, "SpatVoxel")
  expect_true(methods::is(v, "SpatRaster"))
  expect_true(methods::is(v, "SpatVolume"))
  # terra operations still work on the subclass
  expect_equal(terra::nlyr(v), 4)
})

test_that("SpatVoxel validity rejects non-conforming layer names and order", {
  bad_names <- make_voxel_rast()
  names(bad_names) <- c("a", "b", "c", "d")
  expect_error(methods::new("SpatVoxel", bad_names), "\\{variable\\}_depth=")

  unsorted <- make_voxel_rast(depths = c(300, 200, 100, 0))
  expect_error(methods::new("SpatVoxel", unsorted), "shallow to deep")
})

test_that("SpatEnvelope validity requires exactly depth_min, depth_max", {
  expect_error(methods::new("SpatEnvelope", make_voxel_rast()),
               "exactly: depth_min, depth_max")
})

test_that("voxel_to_envelope() defaults to the non-NA vertical extent", {
  v <- methods::new("SpatVoxel", make_voxel_rast())
  e <- voxel_to_envelope(v)

  expect_s4_class(e, "SpatEnvelope")
  expect_identical(names(e), c("depth_min", "depth_max"))

  vals <- terra::values(e)
  expect_equal(unname(vals[, "depth_min"]), c(0, 100, 0, NA))
  expect_equal(unname(vals[, "depth_max"]), c(200, 200, 300, NA))
})

test_that("voxel_to_envelope() fills interior gaps (lossy collapse)", {
  # cell 1 has values at 0 m and 200 m but not at 100 m; the envelope is solid
  v <- methods::new("SpatVoxel", make_voxel_rast())
  vals <- terra::values(voxel_to_envelope(v))

  expect_equal(unname(vals[1, "depth_min"]), 0)
  expect_equal(unname(vals[1, "depth_max"]), 200)
})

test_that("voxel_to_envelope() bounds the depths where the predicate holds", {
  v <- methods::new("SpatVoxel", make_voxel_rast())
  vals <- terra::values(voxel_to_envelope(v, function(x) x > 15))

  # only cell 2 exceeds 15, at 100 m and 200 m
  expect_equal(unname(vals[, "depth_min"]), c(NA, 100, NA, NA))
  expect_equal(unname(vals[, "depth_max"]), c(NA, 200, NA, NA))
})

test_that("voxel_to_envelope() returns NA where the predicate never holds", {
  v <- methods::new("SpatVoxel", make_voxel_rast())
  vals <- terra::values(voxel_to_envelope(v, function(x) x > 1e6))

  expect_true(all(is.na(vals)))
})

test_that("voxel_to_envelope() rejects a non-function fun", {
  v <- methods::new("SpatVoxel", make_voxel_rast())
  expect_error(voxel_to_envelope(v, "extent"), "must be a function")
})

test_that("voxel_to_envelope() accepts a plain multi-depth SpatRaster", {
  e <- voxel_to_envelope(make_voxel_rast())
  expect_s4_class(e, "SpatEnvelope")
})
