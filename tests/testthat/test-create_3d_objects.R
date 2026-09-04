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

test_that("as_envelope() handles an empty footprint", {
  empty <- make_footprint(c(NA, NA, NA, NA))
  e <- as_envelope(empty, 0, 200)

  expect_s4_class(e, "SpatEnvelope")
  expect_true(all(is.na(terra::values(e))))
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

test_that("voxel_to_envelope() handles a single-depth voxel", {
  # a one-layer voxel collapses to a zero-thickness envelope at that depth
  v <- methods::new("SpatVoxel",
                    make_multidepth_rast(depths = 50,
                                         vals = list(c(10, NA, 5, NA))))
  vals <- terra::values(voxel_to_envelope(v))

  expect_equal(unname(vals[, "depth_min"]), c(50, NA, 50, NA))
  expect_equal(unname(vals[, "depth_max"]), c(50, NA, 50, NA))
})

# envelope_to_voxel() ----
test_that("envelope_to_voxel() rejects invalid input param types", {
  # a multi-depth raster is a plausible-looking but wrong input: it is the
  # voxel form of a 3D domain, not the envelope form
  bad_envel <- make_multidepth_rast()
  good_envel <- as_envelope(make_footprint(), depth_min = 0, depth_max = 200)

  bad_depths <- c("hello", 100, "depths")
  good_depths <- c(0, 50, 100, 150, 200, 300, 600)

  # check for param x valid SpatEnvelope
  expect_error(
    envelope_to_voxel(x = bad_envel, depths = good_depths),
    "`x` needs to be of `SpatEnvelope` class",
    fixed = TRUE
  )

  # check for param depths valid numeric
  expect_error(
    envelope_to_voxel(x = good_envel, depths = bad_depths),
    "`depths` needs to be array coercible to numeric type",
    fixed = TRUE
  )
  expect_error(
    envelope_to_voxel(x = good_envel, depths = numeric(0)),
    "`depths` needs to be array coercible to numeric type",
    fixed = TRUE
  )

  # check for param fun valid function
  expect_error(
    envelope_to_voxel(x = good_envel, depths = good_depths, fun = "not a function"),
    "`fun` needs to be a function",
    fixed = TRUE
  )

  # check for param varname valid string
  expect_error(
    envelope_to_voxel(x = good_envel, depths = good_depths, varname = 100),
    "`varname` needs to be a string",
    fixed = TRUE
  )
  expect_error(
    envelope_to_voxel(x = good_envel, depths = good_depths,
                      varname = c("presence", "absence")),
    "`varname` needs to be a string",
    fixed = TRUE
  )
})

test_that("envelope_to_voxel() accepts depths that merely coerce to numeric", {
  good_envel <- as_envelope(make_footprint(), depth_min = 0, depth_max = 200)

  # character and integer depths are coerced rather than rejected as the wrong
  # type, and the coerced values are what the layer names are built from
  expect_identical(
    names(envelope_to_voxel(good_envel, depths = c("0", "100"))),
    paste0("presence_depth=", c(0, 100))
  )
  expect_identical(
    names(envelope_to_voxel(good_envel, depths = 0:3)),
    paste0("presence_depth=", 0:3)
  )
})

test_that("envelope_to_voxel() generates voxel from envelope", {
  temp_r <- make_footprint(c(1,1,1,1))
  # Create 2x2 simple envelope with depth_min and depth_max layers. 
  envel <- as_envelope(temp_r, depth_min = 70, depth_max = 210)

  # Defined depth layers 
  a_depths <- c(0, 50, 100, 150, 200, 300, 400)

  # Expected result
  expected_vox <- lapply(a_depths, function(x) {
    if(x > 70 & x < 210) {
      r <- terra::setValues(temp_r, 1)
    } else {
      r <- terra::setValues(temp_r, NA)
    }
    names(r) <- paste0("test_depth=", x)
    r
  }) %>% as_voxel()

  got <- envelope_to_voxel(x = envel, depths = a_depths, varname = "test")

  # identical() is too strict for this: it separates a stack built from seven
  # single-layer rasters from one seven-layer raster, even when the grid, the
  # names and every cell value agree.
  expect_s4_class(got, "SpatVoxel")
  expect_identical(names(got), names(expected_vox))
  expect_equal(terra::values(got), terra::values(expected_vox))
})

test_that("envelope_to_voxel() includes depths that sit exactly on the limits", {
  envel <- as_envelope(make_footprint(c(1, 1, 1, 1)), depth_min = 50, depth_max = 200)
  vals <- terra::values(envelope_to_voxel(envel, depths = c(0, 50, 100, 200, 300)))

  # 50 and 200 are the limits themselves, and are occupied
  expect_equal(unname(vals[1, ]), c(NA, 1, 1, 1, NA))
})

test_that("envelope_to_voxel() leaves cells absent from the envelope empty", {
  # cell 4 of make_footprint() is NA, so it is NA at every depth
  envel <- as_envelope(make_footprint(), depth_min = 0, depth_max = 200)
  vals <- terra::values(envelope_to_voxel(envel, depths = c(0, 100, 200)))

  expect_equal(unname(vals[, 1]), c(1, 1, 1, NA))
  expect_true(all(is.na(vals[4, ])))
})

test_that("envelope_to_voxel() honours per-cell depth limits", {
  fp <- make_footprint()
  dmin <- terra::setValues(terra::rast(fp), c(0, 100, 200, 0))
  dmax <- terra::setValues(terra::rast(fp), c(100, 300, 300, 300))
  envel <- as_envelope(fp, depth_min = dmin, depth_max = dmax)

  vals <- terra::values(envelope_to_voxel(envel, depths = c(0, 100, 200, 300)))

  expect_equal(unname(vals[1, ]), c(1, 1, NA, NA))    # [0, 100]
  expect_equal(unname(vals[2, ]), c(NA, 1, 1, 1))     # [100, 300]
  expect_equal(unname(vals[3, ]), c(NA, NA, 1, 1))    # [200, 300]
  expect_true(all(is.na(vals[4, ])))                  # absent footprint
})

test_that("envelope_to_voxel() writes a vertical profile from `fun`", {
  fp <- make_footprint()
  dmax <- terra::setValues(terra::rast(fp), c(100, 300, 300, 300))
  envel <- as_envelope(fp, depth_min = 0, depth_max = dmax)

  # share of time spent at each occupied depth: depends on how many there are,
  # so the two distinct intervals must get different profiles
  v <- envelope_to_voxel(envel, depths = c(0, 100, 200, 300),
                         fun = function(d) rep(1 / length(d), length(d)),
                         varname = "time")
  vals <- terra::values(v)

  expect_identical(names(v), paste0("time_depth=", c(0, 100, 200, 300)))
  expect_equal(unname(vals[1, ]), c(0.5, 0.5, NA, NA))
  expect_equal(unname(vals[2, ]), rep(0.25, 4))
})

test_that("envelope_to_voxel() passes the occupied depths to `fun`", {
  envel <- as_envelope(make_footprint(c(1, 1, 1, 1)), depth_min = 50, depth_max = 200)

  seen <- NULL
  envelope_to_voxel(envel, depths = c(0, 50, 100, 200, 300),
                    fun = function(d) { seen <<- d; 1 })

  expect_equal(seen, c(50, 100, 200))
})

test_that("envelope_to_voxel() rejects a `fun` that returns the wrong shape", {
  envel <- as_envelope(make_footprint(c(1, 1, 1, 1)), depth_min = 0, depth_max = 300)

  expect_error(
    envelope_to_voxel(envel, depths = c(0, 100, 200, 300),
                      fun = function(d) c(1, 2)),
    "one value per depth"
  )
  expect_error(
    envelope_to_voxel(envel, depths = c(0, 100, 200, 300),
                      fun = function(d) "deep"),
    "must return numeric values"
  )
})

test_that("envelope_to_voxel() sorts and deduplicates the requested depths", {
  envel <- as_envelope(make_footprint(c(1, 1, 1, 1)), depth_min = 0, depth_max = 300)

  v <- envelope_to_voxel(envel, depths = c(200, 0, 100, 200))

  expect_identical(names(v), paste0("presence_depth=", c(0, 100, 200)))
})

test_that("envelope_to_voxel() rejects negative depths (positive-down convention)", {
  envel <- as_envelope(make_footprint(), depth_min = 0, depth_max = 200)

  expect_error(envelope_to_voxel(envel, depths = c(-100, 0, 100)),
               "positive metres increasing downward")
})

test_that("envelope_to_voxel() warns when an envelope resolves to no depth level", {
  # [10, 20] falls between the standard levels, so the cell has nowhere to go
  envel <- as_envelope(make_footprint(c(1, 1, 1, 1)), depth_min = 10, depth_max = 20)

  expect_warning(v <- envelope_to_voxel(envel, depths = c(0, 100, 200)),
                 "contains none of")
  expect_true(all(is.na(terra::values(v))))
})

test_that("envelope_to_voxel() round-trips a voxel built on the same depths", {
  # a gap-free voxel is the case where the two conversions are inverses
  depths <- c(0, 100, 200, 300)
  solid <- make_multidepth_rast(depths = depths,
                                vals = list(c(10, NA, 5, NA),
                                            c(11, 20, 6, NA),
                                            c(12, 21, 7, NA),
                                            c(NA, 22, 8, NA)))
  v <- as_voxel(solid)

  back <- envelope_to_voxel(voxel_to_envelope(v), depths = depths, varname = "temp")

  # presence pattern is recovered exactly; the values themselves are not, since
  # an envelope carries only the depth limits
  expect_identical(names(back), names(v))
  expect_equal(is.na(terra::values(back)), is.na(terra::values(v)))
})

# vect_to_envelope() ----

test_that("vect_to_envelope() checks for correct params", {
  expect_error(
    vect_to_envelope("test", make_template(), 0, 10),
    "`polygon` needs to be of class SpatVector, sf, or sfc"
  )
  expect_error(
    vect_to_envelope(make_polygon(), "test", 0, 10),
    "`template` needs to be of class SpatRaster"
  )
})

test_that("vect_to_envelope() provides meaningful message when polygon and template don't overlap", {
  # Create raster that doesn't overlap with make_polygon()
  template_r <- rast(
    nrows = 5, ncols = 5, 
    xmin = 5, xmax = 10, ymin = 5, ymax = 10, crs = "EPSG:4326"
  )
  expect_error(
    vect_to_envelope(make_polygon(), template_r, 0, 10),
    "All output cell values are NA. `polygon` and `template` may not spatially overlap."
  )
})

test_that("vect_to_envelope() checks for agreement of CRS between inputs", {
  template_r <- rast(
    nrows = 5, ncols = 5, 
    xmin = 0, xmax = 5, ymin = 0, ymax = 5, crs = "EPSG:3857"
  )
  expect_error(
    vect_to_envelope(make_polygon(), template_r, 0, 10),
    "`polygon` and `template` have different CRS."
  )

  # TODO: implement check for the depth_min and depth_max inputs
})

test_that("vect_to_envelope() takes single numeric value for depth_min and depth_max", {
  r <- make_template() 

  expected_result <- rast(c(
    depth_min = rast(r, vals = 10), 
    depth_max = rast(r, vals = 20)
  )) 
  expected_result$depth_min <- expected_result$depth_min %>% 
    mask(make_polygon())
  expected_result$depth_max <- expected_result$depth_max %>% 
    mask(make_polygon())
  expected_result <- as_envelope(expected_result)

  result <- vect_to_envelope(make_polygon(), make_template(), depth_min = 10, depth_max = 20) 

  expect_true(identical(result, expected_result))
})

test_that("vect_to_envelope() correctly takes deeper minimum depth in the depth_min list params", {
  r <- make_template()
  terra::values(r) <- seq_len(length(values(r)))

  expected_result <- r %>%
    mask(make_polygon()) %>%
    max(10) 
  names(expected_result) <- "depth_min"
  expected_result$depth_max <- rast(r, vals = 25)
  expected_result <- as_envelope(expected_result)

  result <- vect_to_envelope(make_polygon(), make_template(), depth_min = c(10, r), depth_max = 25) 

  expect_true(identical(result["depth_min"], expected_result["depth_min"]))
})

test_that("vect_to_envelope() correctly takes shallower maximum depth in the depth_max list params", {
  r <- make_template()
  terra::values(r) <- seq_len(length(values(r)))

  expected_result <- rast()
  expected_result$depth_min <- rast(r, vals = 0)
  expected_result$depth_max <- r %>%
    mask(make_polygon()) %>%
    min(10) 
  expected_result <- as_envelope(expected_result)

  result <- vect_to_envelope(make_polygon(), make_template(), depth_min = 0, depth_max = c(10, r)) 

  expect_true(identical(result["depth_max"], expected_result["depth_max"]))
})

# TODO: deal with case where depth_max is shallower than depth_min
test_that("vect_to_envelope() fills NA where depth_max is shallower than depth_min", {
  r <- make_template()
  terra::values(r) <- seq_len(length(values(r)))

  # minimum depth of envelope is 10
  depth_min_rast <- rast(r, vals = 10) 
  # maximum depth is either 16 or the raster r value
  depth_max_rast <- r %>%
    mask(make_polygon()) %>%
    min(16) 

  # valid cells are where depth_max is greater than depth_min
  diffs <- depth_max_rast - depth_min_rast
  msk <- ifel(diffs > 0, 1, NA)

  depth_min_rast <- mask(depth_min_rast, msk)
  depth_max_rast <- mask(depth_max_rast, msk)

  expected_result <- rast(c(
    depth_min = depth_min_rast,
    depth_max = depth_max_rast
  )) %>% as_envelope()

  result <- vect_to_envelope(make_polygon(), make_template(), depth_min = 10, depth_max = c(16, r)) 

  expect_true(identical(result, expected_result))
})

test_that("vect_to_envelope() catches case where all cells depth_min are deeper than depth_max", {
  r <- make_template()
  terra::values(r) <- seq_len(length(values(r)))

  expected_result <- r %>%
    mask(make_polygon()) %>%
    min(10) 
  names(expected_result) <- "depth_max"

  expect_warning(
    vect_to_envelope(make_polygon(), make_template(), depth_min = 50, depth_max = c(10, r)), 
    "All depth_max values are shallower than depth_min. Check `depth_min` and `depth_max`, you may have swapped these two."
  )
})

test_that("vect_to_envelope() accepts SpatVector and sfc as well as sf", {
  expect_s4_class(
    vect_to_envelope(terra::vect(make_polygon()), make_template(), 0, 10),
    "SpatEnvelope"
  )
  expect_s4_class(
    vect_to_envelope(sf::st_geometry(make_polygon()), make_template(), 0, 10),
    "SpatEnvelope"
  )
})

test_that("vect_to_envelope() returns a valid SpatEnvelope, visibly", {
  out <- vect_to_envelope(make_polygon(), make_template(), 0, 10)

  expect_s4_class(out, "SpatEnvelope")
  expect_true(isTRUE(methods::validObject(out)))
  expect_named(out, c("depth_min", "depth_max"))
  # The constructor assigns to `out` last; without a trailing bare `out` the
  # result would come back invisibly and never print at the console.
  expect_true(withVisible(vect_to_envelope(make_polygon(), make_template(), 0, 10))$visible)
})

# Ported from voxelize_range(): the seafloor is now just another `depth_max`
# constraint rather than a dedicated `bathymetry` argument.
test_that("vect_to_envelope() clamps depth_max to the seafloor where it is shallower", {
  seafloor <- make_template(seq(10, 250, length.out = 25))

  out <- vect_to_envelope(make_polygon(), make_template(),
                          depth_min = 50, depth_max = list(200, seafloor))

  got <- terra::values(out$depth_max)
  got <- got[!is.na(got)]
  expect_true(all(got <= 200))
  expect_true(any(got < 200))
})

# Ported from voxelize_range(): cells whose bed sits above the shallowest depth
# the animal occupies carry no envelope at all.
test_that("vect_to_envelope() drops cells where the seafloor is shallower than depth_min", {
  seafloor <- make_template(seq(10, 250, length.out = 25))

  out <- vect_to_envelope(make_polygon(), make_template(),
                          depth_min = 100, depth_max = list(200, seafloor))

  kept <- !is.na(terra::values(out$depth_min))
  expect_true(any(kept))
  expect_true(all(terra::values(seafloor)[kept] > 100))
})

# Ported from voxelize_range()'s bathymetry CRS / resolution checks, which now
# apply to every SpatRaster in a depth list.
test_that("vect_to_envelope() errors on a depth raster that does not align with template", {
  bad_res <- terra::rast(nrows = 9, ncols = 9, xmin = 0, xmax = 5,
                         ymin = 0, ymax = 5, vals = 50, crs = "EPSG:4326")
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list(10, bad_res)),
    "does not align with `template`"
  )

  bad_ext <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 9,
                         ymin = 0, ymax = 9, vals = 50, crs = "EPSG:4326")
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list(10, bad_ext)),
    "does not align with `template`"
  )
})

test_that("vect_to_envelope() errors on a depth raster with a different CRS", {
  # Same extent numbers, different CRS: terra otherwise returns a wrong answer
  # here rather than failing.
  bad_crs <- terra::rast(nrows = 5, ncols = 5, xmin = 0, xmax = 5,
                         ymin = 0, ymax = 5, vals = 50, crs = "EPSG:3857")
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list(10, bad_crs)),
    "different CRS than `template`"
  )
})

test_that("vect_to_envelope() rejects empty and unusable depth inputs", {
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), list(), 10),
    "`depth_min` is empty"
  )
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list()),
    "`depth_max` is empty"
  )
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list(10, "deep")),
    "must be numeric or a SpatRaster"
  )
  # `na.rm = TRUE` would drop an NA silently, widening rather than narrowing.
  expect_error(
    vect_to_envelope(make_polygon(), make_template(), 0, list(10, NA_real_)),
    "is NA"
  )
})

test_that("vect_to_envelope() matches voxelize_range() on the seafloor-clamped case", {
  # Migration guard: delete alongside voxelize_range().
  seafloor <- make_template(seq(10, 250, length.out = 25))

  old <- voxelize_range(polygons = make_polygon(), voxel = make_template(),
                        bathymetry = seafloor, depth_min = 50, depth_max = 200)
  new <- vect_to_envelope(make_polygon(), make_template(),
                          depth_min = 50, depth_max = list(200, seafloor))

  expect_equal(as.vector(terra::values(new$depth_min)),
               as.vector(terra::values(old$depth_min)))
  expect_equal(as.vector(terra::values(new$depth_max)),
               as.vector(terra::values(old$depth_max)))
})

test_that("create_study_voxel() bundles grid, positive seafloor, and sorted depths", {
  sv <- create_study_voxel(
    template = make_template(),
    bathymetry = make_template(-500),
    depths = c(100, 0, 50)
  )
  expect_s3_class(sv, "study_voxel")
  expect_named(sv, c("grid", "seafloor", "depths"))
  expect_equal(sv$depths, c(0, 50, 100))
  # Elevation -500 becomes positive seafloor depth 500.
  vals <- terra::values(sv$seafloor)
  expect_true(all(vals == 500, na.rm = TRUE))
})

# create_study_voxel() ----

test_that("create_study_voxel() clamps land (positive elevation) to zero depth", {
  sv <- create_study_voxel(make_template(), make_template(120), depths = c(0, 100))
  vals <- terra::values(sv$seafloor)
  expect_true(all(vals == 0, na.rm = TRUE))
})

test_that("create_study_voxel() validates its inputs", {
  expect_error(create_study_voxel("nope", make_template(), 1), "template")
  expect_error(create_study_voxel(make_template(), "nope", 1), "bathymetry")
  expect_error(create_study_voxel(make_template(), make_template(), "nope"), "depths")
})

# voxelize_range() ----

test_that("voxelize_range() accepts a study_voxel and derives the seafloor", {
  skip_if_not_installed("sf")
  sv <- create_study_voxel(make_template(), make_template(-500), depths = c(0, 100))
  out <- voxelize_range(
    polygons = make_polygon(), voxel = sv,
    depth_min = 0, depth_max = 200
  )
  expect_named(out, c("depth_min", "depth_max"))
  # Seafloor at 500 m, requested max 200 m -> not clamped, present cells = 200.
  vals <- terra::values(out[["depth_max"]])
  expect_true(all(vals[!is.na(vals)] == 200))
})

test_that("voxelize_range() errors when voxel is a SpatRaster and bathymetry is missing", {
  skip_if_not_installed("sf")
  expect_error(
    voxelize_range(make_polygon(), make_template(), depth_min = 0, depth_max = 100),
    "bathymetry"
  )
})

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

test_that("voxelize_range() returns depth_min and depth_max layers", {
  skip_if_not_installed("sf")
  out <- voxelize_range(
    polygons = make_polygon(),
    voxel = make_grid(),
    bathymetry = make_bathy(500),
    depth_min = 0,
    depth_max = 200
  )
  expect_named(out, c("depth_min", "depth_max"))
  expect_s4_class(out, "SpatRaster")
})

test_that("voxelize_range() assigns depth_min to cells inside polygon", {
  skip_if_not_installed("sf")
  out <- voxelize_range(
    polygons = make_polygon(),
    voxel = make_grid(),
    bathymetry = make_bathy(500),
    depth_min = 10,
    depth_max = 200
  )
  vals <- terra::values(out[["depth_min"]])
  inside <- vals[!is.na(vals)]
  expect_true(all(inside == 10))
  expect_true(any(is.na(vals)))  # cells outside polygon
})

test_that("voxelize_range() clamps depth_max to seafloor where shallower", {
  skip_if_not_installed("sf")
  # Bathymetry 100m everywhere; requested depth_max = 500m -> clamp to 100.
  out <- voxelize_range(
    polygons = make_polygon(),
    voxel = make_grid(),
    bathymetry = make_bathy(100),
    depth_min = 0,
    depth_max = 500
  )
  vals <- terra::values(out[["depth_max"]])
  vals <- vals[!is.na(vals)]
  expect_true(all(vals == 100))
})

test_that("voxelize_range() drops cells where seafloor is shallower than depth_min", {
  skip_if_not_installed("sf")
  # Bathymetry 50m; depth_min = 200m -> species cannot be present anywhere.
  out <- voxelize_range(
    polygons = make_polygon(),
    voxel = make_grid(),
    bathymetry = make_bathy(50),
    depth_min = 200,
    depth_max = 500
  )
  expect_true(all(is.na(terra::values(out[["depth_min"]]))))
  expect_true(all(is.na(terra::values(out[["depth_max"]]))))
})

test_that("voxelize_range() errors on mismatched bathymetry CRS", {
  skip_if_not_installed("sf")
  bad_bathy <- terra::rast(nrows = 5, ncols = 5,
                           xmin = 0, xmax = 5, ymin = 0, ymax = 5,
                           crs = "EPSG:3857")
  terra::values(bad_bathy) <- 500
  expect_error(
    voxelize_range(make_polygon(), make_grid(), bad_bathy, 0, 100),
    "CRS"
  )
})

test_that("voxelize_range() errors on mismatched bathymetry resolution", {
  skip_if_not_installed("sf")
  bad_bathy <- terra::rast(nrows = 10, ncols = 10,
                           xmin = 0, xmax = 5, ymin = 0, ymax = 5,
                           crs = "EPSG:4326")
  terra::values(bad_bathy) <- 500
  expect_error(
    voxelize_range(make_polygon(), make_grid(), bad_bathy, 0, 100),
    "resolution"
  )
})