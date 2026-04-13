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
