# Helper: 2x2 voxel over four standard depths, cell 1 has an interior gap
make_multidepth_rast <- function(depths = c(0, 100, 200, 300),
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
  v <- methods::new("SpatVoxel", make_multidepth_rast())

  expect_s4_class(v, "SpatVoxel")
  expect_true(methods::is(v, "SpatRaster"))
  expect_true(methods::is(v, "SpatVolume"))
  # terra operations still work on the subclass
  expect_equal(terra::nlyr(v), 4)
})

test_that("SpatVoxel validity rejects non-conforming layer names and order", {
  bad_names <- make_multidepth_rast()
  names(bad_names) <- c("a", "b", "c", "d")
  expect_error(methods::new("SpatVoxel", bad_names), "\\{variable\\}_depth=")

  unsorted <- make_multidepth_rast(depths = c(300, 200, 100, 0))
  expect_error(methods::new("SpatVoxel", unsorted), "shallow to deep")
})

test_that("SpatEnvelope validity requires exactly depth_min, depth_max", {
  expect_error(methods::new("SpatEnvelope", make_multidepth_rast()),
               "exactly: depth_min, depth_max")
})

# voxel_to_envelope() ---- 
test_that("voxel_to_envelope() gracefully rejects non SpatVoxel object as input param", {
  not_voxel <- make_multidepth_rast()
  expect_error(voxel_to_envelope(not_voxel))

  voxel <- as_voxel(not_voxel)
  expect_true(methods::is(voxel, "SpatVoxel"))
})

test_that("voxel_to_envelope() rejects a non-function fun", {
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  expect_error(voxel_to_envelope(v, "extent"), "must be a function")
})


test_that("voxel_to_envelope() defaults to the non-NA vertical extent", {
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  e <- voxel_to_envelope(v)

  expect_s4_class(e, "SpatEnvelope")
  expect_identical(names(e), c("depth_min", "depth_max"))

  vals <- terra::values(e)
  expect_equal(unname(vals[, "depth_min"]), c(0, 100, 0, NA))
  expect_equal(unname(vals[, "depth_max"]), c(200, 200, 300, NA))
})

test_that("voxel_to_envelope() fills interior gaps (lossy collapse)", {
  # cell 1 has values at 0 m and 200 m but not at 100 m; the envelope is solid
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  vals <- terra::values(voxel_to_envelope(v))

  expect_equal(unname(vals[1, "depth_min"]), 0)
  expect_equal(unname(vals[1, "depth_max"]), 200)
})

test_that("voxel_to_envelope() bounds the depths where the predicate holds", {
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  vals <- terra::values(voxel_to_envelope(v, function(x) x > 15))

  # only cell 2 exceeds 15, at 100 m and 200 m
  expect_equal(unname(vals[, "depth_min"]), c(NA, 100, NA, NA))
  expect_equal(unname(vals[, "depth_max"]), c(NA, 200, NA, NA))
})

test_that("voxel_to_envelope() returns NA where the predicate never holds", {
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  vals <- terra::values(voxel_to_envelope(v, function(x) x > 1e6))

  expect_true(all(is.na(vals)))
})

# as_voxel() ----

test_that("as_voxel() wraps a conforming multi-depth SpatRaster", {
  v <- as_voxel(make_multidepth_rast())

  expect_s4_class(v, "SpatVoxel")
  expect_true(methods::is(v, "SpatVolume"))
  expect_identical(names(v), paste0("temp_depth=", c(0, 100, 200, 300)))
})

test_that("as_voxel() is idempotent", {
  v <- as_voxel(make_multidepth_rast())

  expect_s4_class(as_voxel(v), "SpatVoxel")
  expect_identical(names(as_voxel(v)), names(v))
})

test_that("as_voxel() sorts layers shallow to deep instead of rejecting them", {
  # new() rejects unsorted input; the constructor repairs it
  unsorted <- make_multidepth_rast(depths = c(300, 200, 100, 0))
  expect_error(methods::new("SpatVoxel", unsorted), "shallow to deep")

  v <- as_voxel(unsorted)
  expect_s4_class(v, "SpatVoxel")
  expect_identical(names(v), paste0("temp_depth=", c(0, 100, 200, 300)))
})

test_that("as_voxel() sorting carries the values with the layers", {
  unsorted <- make_multidepth_rast(
    depths = c(300, 0),
    vals = list(c(1, 2, 3, 4), c(5, 6, 7, 8))
  )
  v <- as_voxel(unsorted)

  expect_identical(names(v), paste0("temp_depth=", c(0, 300)))
  # the 0 m layer must still hold the values it had before the sort
  expect_equal(unname(terra::values(v[["temp_depth=0"]])[, 1]), c(5, 6, 7, 8))
})

test_that("as_voxel() builds layer names from `depths`", {
  r <- make_multidepth_rast()
  names(r) <- c("a", "b", "c", "d")

  v <- as_voxel(r, depths = c(0, 100, 200, 300), varname = "temp")
  expect_identical(names(v), paste0("temp_depth=", c(0, 100, 200, 300)))
})

test_that("as_voxel() accepts a list of single-depth SpatRasters", {
  r <- make_multidepth_rast()
  lst <- lapply(seq_len(terra::nlyr(r)), function(i) r[[i]])

  expect_s4_class(as_voxel(lst), "SpatVoxel")
})

test_that("as_voxel() rejects non-conforming names and says how to fix it", {
  r <- make_multidepth_rast()
  names(r) <- c("a", "b", "c", "d")

  expect_error(as_voxel(r), "do not follow")
  expect_error(as_voxel(r), "Pass `depths`")
})

test_that("as_voxel() rejects negative depths rather than negating them", {
  expect_error(
    as_voxel(make_multidepth_rast(), depths = c(0, -100, -200, -300)),
    "positive metres increasing downward"
  )
})

test_that("as_voxel() rejects duplicate depths", {
  expect_error(as_voxel(make_multidepth_rast(), depths = c(0, 100, 100, 300)),
               "duplicate depth")
})

test_that("as_voxel() rejects a mismatched `depths` length", {
  expect_error(as_voxel(make_multidepth_rast(), depths = c(0, 100)),
               "one value per layer")
})

test_that("as_voxel() rejects a non-raster input", {
  expect_error(as_voxel("not a raster"), "must be a SpatRaster")
})

test_that("as_voxel() output is accepted by voxel_to_envelope()", {
  e <- voxel_to_envelope(as_voxel(make_multidepth_rast()))
  expect_s4_class(e, "SpatEnvelope")
})

