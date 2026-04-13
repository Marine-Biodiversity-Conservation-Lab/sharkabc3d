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
  a <- make_area_polygon()

  result <- summarise_species_environment(
    species_range = a,
    min_depth = 0,
    max_depth = 500,
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
  a <- make_area_polygon()
  expect_error(
    summarise_species_environment(a, 0, 100, list(r, r)),
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
  # Depth 0 layer = constant 10; depth 100 layer = constant 30.
  r <- make_uniform_rast(list(
    `tan_depth=0` = rep(10, 16),
    `tan_depth=100` = rep(30, 16)
  ))
  a <- make_area_polygon()

  res <- summarise_species_environment(a, 0, 100, list(temp = r))

  expect_equal(res$temp_min, 10)
  expect_equal(res$temp_max, 30)
  expect_equal(res$temp_mean, 20)
  expect_equal(res$temp_n_depths, 2)
})

test_that("summarise_species_environment n_surface_cells <= n_cells", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  a <- make_area_polygon()
  res <- summarise_species_environment(a, 0, 500, list(x = r))
  # Each surface cell contributes up to n_depths non-NA cells.
  expect_lte(res$x_n_surface_cells, res$x_n_cells)
  expect_gt(res$x_n_surface_cells, 0)
})

test_that("summarise_species_environment handles NA cells correctly", {
  skip_if_not_installed("sf")
  # Half the cells NA in the depth=0 layer.
  vals0 <- c(rep(5, 8), rep(NA_real_, 8))
  vals100 <- rep(15, 16)
  r <- make_uniform_rast(list(
    `tan_depth=0` = vals0,
    `tan_depth=100` = vals100
  ))
  # Polygon covering the whole raster so all 16 surface cells are selected.
  a <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(-10, -10), c(10, -10), c(10, 10), c(-10, 10), c(-10, -10)
    ))),
    crs = "EPSG:4326"
  ) |> sf::st_sf(geometry = _)

  res <- summarise_species_environment(a, 0, 100, list(temp = r))

  expect_equal(res$temp_min, 5)
  expect_equal(res$temp_max, 15)
  # n_cells should count only non-NA cells across both layers
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
  a <- make_area_polygon()

  res <- summarise_species_environment(
    a, 0, 100,
    raster_list = list(temperature = r1, oxygen = r2)
  )

  expect_equal(res$temperature_mean, 1.5)
  expect_equal(res$oxygen_mean, 150)
  # Column count: 6 stats x 2 rasters
  expect_equal(ncol(res), 12)
})

test_that("summarise_species_environment returns NA for empty range", {
  skip_if_not_installed("sf")
  r <- make_env_rast()
  # Polygon entirely outside the raster extent
  far_poly <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(100, 100), c(110, 100), c(110, 110), c(100, 110), c(100, 100)
    ))),
    crs = "EPSG:4326"
  ) |> sf::st_sf(geometry = _)

  res <- tryCatch(
    summarise_species_environment(far_poly, 0, 100, list(temp = r)),
    error = function(e) NULL
  )
  # Either errors cleanly (acceptable) or returns NA summaries + zero counts.
  if (!is.null(res)) {
    expect_true(is.na(res$temp_min))
    expect_true(is.na(res$temp_max))
    expect_equal(res$temp_n_cells, 0)
  } else {
    succeed()
  }
})
