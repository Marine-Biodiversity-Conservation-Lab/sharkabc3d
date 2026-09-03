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

# as_envelope() ----

# Helper: 2x2 footprint, cells 1-3 present, cell 4 absent. Values are
# deliberately varied (and one is 0) because only their non-NA-ness counts.
make_footprint <- function(vals = c(1, 5, 0, NA)) {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  terra::setValues(r, vals)
}

test_that("as_envelope() builds a SpatEnvelope from a footprint and constant depths", {
  e <- as_envelope(make_footprint(), depth_min = 0, depth_max = 200)

  expect_s4_class(e, "SpatEnvelope")
  expect_true(methods::is(e, "SpatVolume"))
  expect_identical(names(e), c("depth_min", "depth_max"))

  vals <- terra::values(e)
  expect_equal(unname(vals[, "depth_min"]), c(0, 0, 0, NA))
  expect_equal(unname(vals[, "depth_max"]), c(200, 200, 200, NA))
})

test_that("as_envelope() reads only the non-NA pattern of the footprint", {
  # Values differ wildly, including a zero and a negative; presence does not.
  a <- as_envelope(make_footprint(c(1, 5, 0, NA)), 10, 20)
  b <- as_envelope(make_footprint(c(-7, 0.5, 999, NA)), 10, 20)

  expect_equal(terra::values(a), terra::values(b))
})

test_that("as_envelope() keeps the grid of the footprint", {
  fp <- make_footprint()
  e <- as_envelope(fp, 0, 200)

  expect_true(terra::compareGeom(e, fp, stopOnError = FALSE))
})

test_that("as_envelope() accepts per-cell depth limits as single-layer rasters", {
  fp <- make_footprint()
  dmin <- terra::setValues(terra::rast(fp), c(0, 50, 100, 150))
  dmax <- terra::setValues(terra::rast(fp), c(100, 200, 300, 400))

  vals <- terra::values(as_envelope(fp, depth_min = dmin, depth_max = dmax))

  expect_equal(unname(vals[, "depth_min"]), c(0, 50, 100, NA))
  expect_equal(unname(vals[, "depth_max"]), c(100, 200, 300, NA))
})

test_that("as_envelope() mixes a constant limit with a per-cell limit", {
  fp <- make_footprint()
  dmax <- terra::setValues(terra::rast(fp), c(100, 200, 300, 400))

  vals <- terra::values(as_envelope(fp, depth_min = 10, depth_max = dmax))

  expect_equal(unname(vals[, "depth_min"]), c(10, 10, 10, NA))
  expect_equal(unname(vals[, "depth_max"]), c(100, 200, 300, NA))
})

test_that("as_envelope() clamps depth_max to the seafloor", {
  fp <- make_footprint()
  # Cell 3's seabed is shallower than the 200 m limit, so it truncates there.
  seabed <- terra::setValues(terra::rast(fp), c(500, 500, 50, 500))

  vals <- terra::values(as_envelope(fp, 0, 200, seafloor = seabed))

  expect_equal(unname(vals[, "depth_min"]), c(0, 0, 0, NA))
  expect_equal(unname(vals[, "depth_max"]), c(200, 200, 50, NA))
})

test_that("as_envelope() drops cells whose seafloor is shallower than depth_min", {
  fp <- make_footprint()
  # Cell 2's seabed (30 m) is above the species' 100 m minimum: no water column
  # left, so the cell is absent in both layers.
  seabed <- terra::setValues(terra::rast(fp), c(500, 30, 150, 500))

  vals <- terra::values(as_envelope(fp, 100, 200, seafloor = seabed))

  expect_equal(unname(vals[, "depth_min"]), c(100, NA, 100, NA))
  expect_equal(unname(vals[, "depth_max"]), c(200, NA, 150, NA))
})

test_that("as_envelope() treats a missing seafloor value as absent", {
  fp <- make_footprint(c(1, 1, 1, 1))
  seabed <- terra::setValues(terra::rast(fp), c(500, NA, 500, 500))

  vals <- terra::values(as_envelope(fp, 0, 200, seafloor = seabed))

  expect_true(all(is.na(vals[2, ])))
  expect_equal(unname(vals[, "depth_max"]), c(200, NA, 200, 200))
})

test_that("as_envelope() promotes a raster that already has the depth layers", {
  fp <- make_footprint()
  plain <- c(
    terra::setValues(terra::rast(fp), c(0, 0, 0, NA)),
    terra::setValues(terra::rast(fp), c(200, 200, 200, NA))
  )
  names(plain) <- c("depth_min", "depth_max")

  e <- as_envelope(plain)

  expect_s4_class(e, "SpatEnvelope")
  expect_equal(terra::values(e), terra::values(plain))
})

test_that("as_envelope() clamps an already-built envelope to a seafloor", {
  fp <- make_footprint()
  e <- as_envelope(fp, 0, 200)
  seabed <- terra::setValues(terra::rast(fp), c(500, 500, 50, 500))

  vals <- terra::values(as_envelope(e, seafloor = seabed))

  expect_equal(unname(vals[, "depth_max"]), c(200, 200, 50, NA))
})

test_that("as_envelope() is idempotent on its own output", {
  e <- as_envelope(make_footprint(), 0, 200)

  expect_equal(terra::values(as_envelope(e)), terra::values(e))
})

test_that("as_envelope() promotes voxel_to_envelope() output unchanged", {
  v <- methods::new("SpatVoxel", make_multidepth_rast())
  e <- voxel_to_envelope(v)

  expect_equal(terra::values(as_envelope(e)), terra::values(e))
})

test_that("as_envelope() rejects depth arguments alongside existing depth layers", {
  e <- as_envelope(make_footprint(), 0, 200)

  expect_error(as_envelope(e, depth_min = 0, depth_max = 100),
               "already has depth_min and depth_max")
})

test_that("as_envelope() requires depth limits for a bare footprint", {
  expect_error(as_envelope(make_footprint()), "are required")
})

test_that("as_envelope() rejects a multi-layer footprint", {
  expect_error(as_envelope(make_multidepth_rast(), 0, 200), "single-layer footprint")
})

test_that("as_envelope() rejects vector geometry with a pointer to voxelize_range()", {
  poly <- terra::vect("POLYGON ((0 0, 2 0, 2 2, 0 2, 0 0))")

  expect_error(as_envelope(poly, 0, 200), "voxelize_range")
})

test_that("as_envelope() rejects a non-raster x", {
  expect_error(as_envelope(1:10, 0, 200), "must be a SpatRaster")
})

test_that("as_envelope() rejects inverted depth limits", {
  expect_error(as_envelope(make_footprint(), depth_min = 200, depth_max = 0),
               "at least `depth_min`")

  fp <- make_footprint()
  dmax <- terra::setValues(terra::rast(fp), c(300, 300, 5, NA))
  expect_error(as_envelope(fp, depth_min = 10, depth_max = dmax),
               "at least `depth_min`")
})

test_that("as_envelope() rejects negative depths (positive-down convention)", {
  expect_error(as_envelope(make_footprint(), depth_min = -50, depth_max = 200),
               "positive metres increasing downward")
})

test_that("as_envelope() rejects depth limits that are not scalars or rasters", {
  fp <- make_footprint()

  expect_error(as_envelope(fp, depth_min = c(0, 100), depth_max = 200),
               "single non-missing number")
  expect_error(as_envelope(fp, depth_min = NA, depth_max = 200),
               "single non-missing number")
  expect_error(as_envelope(fp, depth_min = "0", depth_max = 200),
               "single non-missing number")
})

test_that("as_envelope() rejects depth and seafloor rasters off the footprint grid", {
  fp <- make_footprint()
  other <- terra::rast(nrows = 4, ncols = 4, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  terra::values(other) <- 100

  expect_error(as_envelope(fp, depth_min = 0, depth_max = other),
               "same grid")
  expect_error(as_envelope(fp, 0, 200, seafloor = other),
               "same grid")
  expect_error(as_envelope(fp, 0, 200, seafloor = make_multidepth_rast()),
               "single-layer SpatRaster")
})

test_that("as_envelope() handles an empty footprint", {
  empty <- make_footprint(c(NA, NA, NA, NA))
  e <- as_envelope(empty, 0, 200)

  expect_s4_class(e, "SpatEnvelope")
  expect_true(all(is.na(terra::values(e))))
})

test_that("as_envelope() output is measurable by calc_volume()", {
  fp <- make_footprint()
  e <- as_envelope(fp, depth_min = 0, depth_max = 100)

  # 3 present cells x 100 m thickness; compare against the same arithmetic.
  area_km2 <- terra::values(terra::cellSize(fp, unit = "km"))[1:3, 1]
  expect_equal(calc_volume(e), sum(area_km2 * 100 / 1000))
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

# envelope_to_voxel() ----
test_that("envelope_to_voxel() rejects invalid input param types", {
  bad_envel <- make_multidepth_rast()
  good_envel <- make_multidepth_rast() %>% as_voxel()

  bad_depths <- c("hello", 100, "depths")
  good_depths <- c(0, 50, 100, 150, 200, 300, 600)

  # check for param x valid SpatEnvelope
  expect_error(
    envelope_to_voxel(x = bad_envel, depths = good_depths),
    "Input error for envelope_to_voxel(): `x` needs to be of `SpatEnvelope` class."
  )
  # check for param depths valid numeric 
  expect_error(
    envelope_to_voxel(x = good_envel, depths = bad_depths),
    "Input error for envelope_to_voxel(): `depths` needs to be array coercible to numeric type."
  )

  # check for param fun valid function 
  expect_error(
    envelope_to_voxel(x = good_envel, depths = good_depths, fun = "not a function"),
    "Input error for envelope_to_voxel(): `fun` needs to be a function."
  )

  # check for param varname valid string 
  expect_error(
    envelope_to_voxel(x = good_envel, depths = bad_depths, varname = 100),
    "Input error for envelope_to_voxel(): `varname` needs to be a string."
  )
})