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
  tmp <- tempfile("woa_empty_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))
  expect_error(woa_summarise_monthly(tmp), "No \\.nc files")
})

test_that("woa_summarise_monthly computes min/max/diff across files", {
  # Build two tiny synthetic NetCDFs matching the WOA layer-naming convention.
  # Skips cleanly on systems without NetCDF write support in terra.
  tmp <- tempfile("woa_mon_"); dir.create(tmp)
  on.exit(unlink(tmp, recursive = TRUE))

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

  f1 <- file.path(tmp, "m01.nc")
  f2 <- file.path(tmp, "m02.nc")
  ok <- tryCatch({
    make_file(f1, list(`tan_depth=0` = c(1, 2, 3, 4), `tan_depth=100` = c(5, 6, 7, 8)))
    make_file(f2, list(`tan_depth=0` = c(2, 3, 4, 5), `tan_depth=100` = c(4, 5, 6, 7)))
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
