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
  sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(-5, -5), c(5, -5), c(5, 5), c(-5, 5), c(-5, -5)
    ))),
    crs = "EPSG:4326"
  ) |> sf::st_sf(geometry = _)
}

make_range_rast_plot <- function(depth_min_vals = rep(0, 16),
                                 depth_max_vals = rep(500, 16),
                                 ncol = 4, nrow = 4) {
  template <- terra::rast(
    nrows = nrow, ncols = ncol,
    xmin = -10, xmax = 10, ymin = -10, ymax = 10,
    crs = "EPSG:4326"
  )
  dmin <- template; terra::values(dmin) <- depth_min_vals; names(dmin) <- "depth_min"
  dmax <- template; terra::values(dmax) <- depth_max_vals; names(dmax) <- "depth_max"
  c(dmin, dmax)
}

test_that("plot_depth_profile returns a ggplot", {
  skip_if_not_installed("sf")
  p <- plot_depth_profile(
    species_name = "Fakus sharkus",
    range_rast = make_range_rast_plot(rep(0, 16), rep(1000, 16)),
    rast_3d = make_env_rast()
  )
  expect_s3_class(p, "ggplot")
})

test_that("plot_depth_profile errors when no cells fall inside the range window", {
  skip_if_not_installed("sf")
  r <- make_env_rast(depths = c(0, 50))
  # Depth window is deeper than any raster layer → no layer has cells in window
  range_rast <- make_range_rast_plot(rep(2000, 16), rep(3000, 16))
  expect_error(
    plot_depth_profile("X", range_rast, r),
    "No cells"
  )
})

test_that("plot_range_at_depth returns a ggplot and uses nearest depth", {
  skip_if_not_installed("sf")
  p <- plot_range_at_depth(
    species_range = make_area_polygon(),
    depth = 75,
    rast_3d = make_env_rast()
  )
  expect_s3_class(p, "ggplot")
  # subtitle should report nearest available depth (50 or 100)
  expect_match(p$labels$subtitle, "Depth: (50|100) m")
})
