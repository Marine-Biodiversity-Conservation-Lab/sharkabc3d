#' test utility for creating small test netCDFs 
make_file <- function(path, values_by_depth) {
  layers <- lapply(names(values_by_depth), function(dn) {
    r <- terra::rast(nrows = 2, ncols = 2,
                      xmin = 0, xmax = 2, ymin = 0, ymax = 2,
                      crs = "EPSG:4326")
    terra::values(r) <- values_by_depth[[dn]]
    names(r) <- dn
    r
  })
  stk <- terra::rast(layers)
  terra::writeCDF(stk, path, overwrite = TRUE, split = TRUE)
}

test_that("woa_cache_dir returns a writable path", {
  path <- woa_cache_dir()
  expect_true(dir.exists(path))
  test_file <- file.path(path, ".write_test")
  writeLines("ok", test_file)
  expect_true(file.exists(test_file))
  unlink(test_file)
})

test_that("woa_cache_dir is stable across calls", {
  expect_identical(woa_cache_dir(), woa_cache_dir())
})

test_that("woa_download errors on unknown variable", {
  expect_error(
    woa_download("nonsense_variable", period = "annual"),
    "Unknown variable"
  )
})

test_that("woa_download errors on unknown resolution", {
  expect_error(
    woa_download("temperature", resolution = "7"),
    "Unknown resolution"
  )
})

test_that("woa_download does not prompt when output_dir is user-supplied", {
  # User-supplied output_dir is already explicit opt-in; no consent prompt.
  # We simulate non-interactive + unknown variable so the variable check
  # fires before any network call.
  tmp <- tempfile("woa_no_prompt_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  expect_error(
    woa_download("nonsense", output_dir = tmp),
    "Unknown variable"
  )
})

test_that("woa_download errors on invalid period", {
  expect_error(
    woa_download("temperature", period = "yearly"),
    "period must be"
  )
  expect_error(
    woa_download("temperature", period = 99),
    "Numeric period"
  )
})

test_that("woa_download caches files and skips re-download", {
  skip_if_offline("www.ncei.noaa.gov")
  skip_on_cran()
  tmp <- tempfile("woa_cache_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  # Use 1-degree resolution for a smaller test file
  path <- tryCatch(
    woa_download("temperature", period = "annual",
                 resolution = "1", output_dir = tmp, quiet = TRUE),
    error = function(e) {
      skip(paste("WOA server unreachable:", conditionMessage(e)))
    }
  )
  expect_true(file.exists(path))
  mtime1 <- file.info(path)$mtime

  # Second call should skip download (cached)
  path2 <- woa_download("temperature", period = "annual",
                        resolution = "1", output_dir = tmp, quiet = TRUE)
  expect_identical(path, path2)
  expect_equal(mtime1, file.info(path)$mtime)
})

test_that("woa_load_nc errors when file missing", {
  expect_error(woa_load_nc("/no/such/file.nc"), "File not found")
})

test_that("woa_summarise_monthly errors on empty dir", {
  skip("woa_summarise_monthly to be retired")
  tmp <- tempfile("woa_empty_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  expect_error(woa_summarise_monthly(tmp), "No \\.nc files")
})

test_that("woa_summarise_monthly computes min/max/diff across files when abbreviated field is two characters long", {
  skip("woa_summarise_monthly to be retired")

  # Build two tiny synthetic NetCDFs matching the WOA layer-naming convention.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  f1 <- file.path(tmp, "m01.nc")
  f2 <- file.path(tmp, "m02.nc")
  ok <- tryCatch({
    make_file(f1, list(`t_an_depth=0` = c(1, 2, 3, 4), `t_an_depth=100` = c(5, 6, 7, 8)))
    make_file(f2, list(`t_an_depth=0` = c(2, 3, 4, 5), `t_an_depth=100` = c(4, 5, 6, 7)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "terra::writeCDF unavailable")

  result <- woa_summarise_monthly(tmp, field = "an")
  expect_named(result, c("min", "max", "diff"))
  expect_equal(terra::nlyr(result$min), 2)
  expect_equal(
    terra::values(result$max[[1]])[, 1],
    c(2, 3, 4, 5)
  )
  expect_equal(
    terra::values(result$diff[[1]])[, 1],
    c(1, 1, 1, 1)
  )
})

test_that("woa_summarise_monthly computes min/max/diff across files when abbreviated field is three characters long", {
  skip("woa_summarise_monthly to be retired")

  # Build two tiny synthetic NetCDFs matching the WOA layer-naming convention.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  f1 <- file.path(tmp, "m01.nc")
  f2 <- file.path(tmp, "m02.nc")
  ok <- tryCatch({
    make_file(f1, list(`t_sea_depth=0` = c(1, 2, 3, 4), `t_sea_depth=100` = c(5, 6, 7, 8)))
    make_file(f2, list(`t_sea_depth=0` = c(2, 3, 4, 5), `t_sea_depth=100` = c(4, 5, 6, 7)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "terra::writeCDF unavailable")

  result <- woa_summarise_monthly(tmp, field = "sea")
  expect_named(result, c("min", "max", "diff"))
  expect_equal(terra::nlyr(result$min), 2)
  expect_equal(
    terra::values(result$max[[1]])[, 1],
    c(2, 3, 4, 5)
  )
  expect_equal(
    terra::values(result$diff[[1]])[, 1],
    c(1, 1, 1, 1)
  )
})

test_that("woa_load_nc catches layer names that do not match WOA one-letter code for oceanographic variables", {
  # Build two tiny synthetic NetCDFs matching the WOA layer-naming convention.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  f1 <- file.path(tmp, "m01.nc")
  ok <- tryCatch({
    make_file(f1, list(`do_sea_depth=0` = c(1, 2, 3, 4), `do_sea_depth=100` = c(5, 6, 7, 8)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "error making netCDF test object, check if terra::writeCDF is available")

  expect_error(
    woa_load_nc(paste0(tmp, "/m01.nc"), field = "sea"),
    "check raster layer names. For WOA data, oceanographic variable one-letter code must be one of: t, s, o, O, A, n, p, i, I."
  )
})

test_that("woa_load_nc catches layer names that do not match WOA code for abbreviated fields", {
  # Build two tiny synthetic NetCDFs matching the WOA layer-naming convention.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  f1 <- file.path(tmp, "m01.nc")
  ok <- tryCatch({
    make_file(f1, list(`o_inc_depth=0` = c(1, 2, 3, 4), `o_inc_depth=100` = c(5, 6, 7, 8)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "error making netCDF test object, check if terra::writeCDF is available")

  expect_error(
    woa_load_nc(paste0(tmp, "/m01.nc")),
    "check raster layer names. For WOA data, field code must be one of: an, mn, dd, sd, se, oa, gp, sdo, sea."
  )
})

test_that("woa_load_nc provides descriptive error if standard field is missing from input netCDF", {
  # Build a tiny synthetic NetCDF carrying only "an" layers.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

  f1 <- file.path(tmp, "m01.nc")
  ok <- tryCatch({
    make_file(f1, list(`t_an_depth=0` = c(1, 2, 3, 4), `t_an_depth=100` = c(5, 6, 7, 8)))
    TRUE
  }, error = function(e) FALSE)
  skip_if_not(ok, "terra::writeCDF unavailable")

  # "sea" is a valid WOA field code, so it clears the `field` argument check,
  # but this file has no sea layers. Without the guard the empty subset fails
  # inside terra with "is.numeric(i) is not TRUE".
  expect_error(
    woa_load_nc(f1, field = "sea"),
    "No layers for field 'sea' in m01.nc. Fields present in this file: an.",
    fixed = TRUE
  )

  # A field that is present still loads normally
  expect_named(
    woa_load_nc(f1, field = "an"),
    c("t_an_depth=0", "t_an_depth=100")
  )
})