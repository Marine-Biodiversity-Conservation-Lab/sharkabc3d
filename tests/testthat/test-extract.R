# Helper: synthetic multi-depth SpatRaster with standard layer naming.
# Covers a 4x4 grid in lon/lat with values = depth * 0.1 + row_index so each
# cell / layer is distinguishable.
make_env_rast <- function(depths = c(0, 50, 100, 500, 1000),
                          variable = "tan",
                          ncol = 4, nrow = 4) {
  layers <- lapply(seq_along(depths), function(i) {
    r <- terra::rast(
      nrows = nrow, ncols = ncol,
      xmin = -10, xmax = 10, ymin = -10, ymax = 10,
      crs = "EPSG:4326"
    )
    terra::values(r) <- seq_len(ncol * nrow) + depths[i] * 0.01
    names(r) <- paste0(variable, "_depth=", depths[i])
    r
  })
  terra::rast(layers)
}

make_area_polygon <- function() {
  # Square covering centre of the raster
  sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(-5, -5), c(5, -5), c(5, 5), c(-5, 5), c(-5, -5)
    ))),
    crs = "EPSG:4326"
  ) |> sf::st_sf(geometry = _)
}

# Build a rasterize_range-style stack (depth_min + depth_max layers) directly
# from a vector of per-cell depth_min and depth_max values. Aligned to the
# grid used by make_env_rast(), so extract_rast_range() doesn't have to
# resample.
make_range_rast <- function(depth_min_vals, depth_max_vals, ncol = 4, nrow = 4) {
  template <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = -10, xmax = 10, ymin = -10, ymax = 10,
    crs = "EPSG:4326"
  )
  dmin <- template; terra::values(dmin) <- depth_min_vals; names(dmin) <- "depth_min"
  dmax <- template; terra::values(dmax) <- depth_max_vals; names(dmax) <- "depth_max"
  c(dmin, dmax)
}

test_that("extract_rast_volume selects the correct depth range", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  a <- make_area_polygon()

  out <- extract_rast_volume(a, min_depth = 40, max_depth = 600, rast_3d = r)

  # depths 50, 100, 500 are the nearest standard layers that bracket 40-600
  expect_equal(terra::nlyr(out), 3)
  expect_true(all(grepl("depth=(50|100|500)$", names(out))))
})

test_that("extract_rast_volume crops to area", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  a <- make_area_polygon()

  out <- extract_rast_volume(a, min_depth = 0, max_depth = 0, rast_3d = r)

  # Extent should shrink from -10..10 to roughly -5..5
  e <- terra::ext(out)
  expect_lt(e[2] - e[1], 20)
})

test_that("extract_rast_volume errors on non-standard layer names", {
  r <- terra::rast(nrows = 4, ncols = 4)
  terra::values(r) <- 1:16
  names(r) <- "not_a_depth_layer"
  expect_error(
    extract_rast_volume(NULL, 0, 100, r),
    "'\\{variable\\}_depth=\\{value\\}'"
  )
})

test_that("summarise_species_environment returns one row per call with expected cols", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  range_rast <- make_range_rast(rep(0, 16), rep(500, 16))

  result <- summarise_species_environment(
    range_rast = range_rast,
    raster_list = list(temp = r, oxy = r)
  )

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  for (prefix in c("temp", "oxy")) {
    for (stat in c("min", "max", "mean",
                   "n_surface_cells", "n_cells", "n_depths")) {
      expect_true(paste(prefix, stat, sep = "_") %in% names(result))
    }
  }
  expect_gt(result$temp_n_depths, 0)
  expect_gt(result$temp_n_cells, 0)
})

test_that("summarise_species_environment rejects unnamed raster_list", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  range_rast <- make_range_rast(rep(0, 16), rep(100, 16))
  expect_error(
    summarise_species_environment(range_rast, list(r, r)),
    "fully named"
  )
})

# Build a raster with known, controlled values so we can check the numeric
# summaries directly. Two depth layers, constant per layer.
make_uniform_rast <- function(depth_values) {
  layers <- lapply(names(depth_values), function(dn) {
    r <- terra::rast(
      nrows = 4, ncols = 4,
      xmin = -10, xmax = 10, ymin = -10, ymax = 10,
      crs = "EPSG:4326"
    )
    terra::values(r) <- depth_values[[dn]]
    names(r) <- dn
    r
  })
  terra::rast(layers)
}

test_that("summarise_species_environment reports correct min/max/mean", {
  skip_if_not_installed("sf")
  r <- make_uniform_rast(list(
    `tan_depth=0` = rep(10, 16),
    `tan_depth=100` = rep(30, 16)
  ))
  range_rast <- make_range_rast(rep(0, 16), rep(100, 16))

  res <- summarise_species_environment(range_rast, list(temp = r))

  expect_equal(res$temp_min, 10)
  expect_equal(res$temp_max, 30)
  expect_equal(res$temp_mean, 20)
  expect_equal(res$temp_n_depths, 2)
})

test_that("summarise_species_environment n_surface_cells <= n_cells", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  range_rast <- make_range_rast(rep(0, 16), rep(500, 16))
  res <- summarise_species_environment(range_rast, list(x = r))
  expect_lte(res$x_n_surface_cells, res$x_n_cells)
  expect_gt(res$x_n_surface_cells, 0)
})

test_that("summarise_species_environment handles NA cells correctly", {
  skip_if_not_installed("sf")
  vals0 <- c(rep(5, 8), rep(NA_real_, 8))
  vals100 <- rep(15, 16)
  r <- make_uniform_rast(list(
    `tan_depth=0` = vals0,
    `tan_depth=100` = vals100
  ))
  range_rast <- make_range_rast(rep(0, 16), rep(100, 16))

  res <- summarise_species_environment(range_rast, list(temp = r))

  expect_equal(res$temp_min, 5)
  expect_equal(res$temp_max, 15)
  # n_cells counts only non-NA cells across both layers
  expect_equal(res$temp_n_cells, 8 + 16)
})

test_that("summarise_species_environment preserves per-raster column prefixes", {
  skip_if_not_installed("sf")
  r1 <- make_uniform_rast(list(
    `tan_depth=0` = rep(1, 16),
    `tan_depth=100` = rep(2, 16)
  ))
  r2 <- make_uniform_rast(list(
    `oan_depth=0` = rep(100, 16),
    `oan_depth=100` = rep(200, 16)
  ))
  range_rast <- make_range_rast(rep(0, 16), rep(100, 16))

  res <- summarise_species_environment(
    range_rast,
    raster_list = list(temperature = r1, oxygen = r2)
  )

  expect_equal(res$temperature_mean, 1.5)
  expect_equal(res$oxygen_mean, 150)
  expect_equal(ncol(res), 12)
})

test_that("summarise_species_environment returns NA when range is all-NA", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  range_rast <- make_range_rast(rep(NA_real_, 16), rep(NA_real_, 16))

  res <- summarise_species_environment(range_rast, list(temp = r))
  expect_true(is.na(res$temp_min))
  expect_true(is.na(res$temp_max))
  expect_equal(res$temp_n_cells, 0)
})

test_that("extract_rast_range masks cells outside per-cell depth window", {
  skip_if_not_installed("sf")
  r <- make_uniform_rast(list(
    `tan_depth=0` = rep(1, 16),
    `tan_depth=100` = rep(2, 16),
    `tan_depth=500` = rep(3, 16)
  ))
  # First 8 cells: 0-100m window; last 8 cells: 0-500m window
  range_rast <- make_range_rast(
    rep(0, 16),
    c(rep(100, 8), rep(500, 8))
  )

  out <- extract_rast_range(range_rast, r)

  # depth=500 layer should have only the last 8 cells non-NA
  vals500 <- terra::values(out[["tan_depth=500"]])
  expect_equal(sum(!is.na(vals500)), 8)
  # depth=100 layer should have all 16 non-NA
  vals100 <- terra::values(out[["tan_depth=100"]])
  expect_equal(sum(!is.na(vals100)), 16)
})

test_that("extract_rast_range rejects a range_rast without depth layers", {
  r <- make_env_rast()
  bad <- terra::rast(nrows = 2, ncols = 2)
  names(bad) <- "foo"
  terra::values(bad) <- 1
  expect_error(extract_rast_range(bad, r), "depth_min")
})

test_that("summarise_species_environment errors when a raster is unaligned", {
  skip_if_not_installed("sf")
  r_ok <- make_env_rast()
  r_bad <- terra::rast(
    nrows = 8, ncols = 8,  # higher resolution → not aligned
    xmin = -10, xmax = 10, ymin = -10, ymax = 10,
    crs = "EPSG:4326"
  )
  terra::values(r_bad) <- 1
  names(r_bad) <- "tan_depth=0"

  range_rast <- make_range_rast(rep(0, 16), rep(100, 16))

  expect_error(
    summarise_species_environment(range_rast, list(ok = r_ok, bad = r_bad)),
    "not aligned with range_rast"
  )
})

test_that("extract_rast_range errors on mismatched geometry", {
  r <- make_env_rast()
  # range_rast at a different resolution → not aligned
  mismatched <- terra::rast(
    nrows = 8, ncols = 8,
    xmin = -10, xmax = 10, ymin = -10, ymax = 10,
    crs = "EPSG:4326"
  )
  dmin <- mismatched; terra::values(dmin) <- 0; names(dmin) <- "depth_min"
  dmax <- mismatched; terra::values(dmax) <- 500; names(dmax) <- "depth_max"
  range_rast <- c(dmin, dmax)

  expect_error(extract_rast_range(range_rast, r), "not aligned")
})
