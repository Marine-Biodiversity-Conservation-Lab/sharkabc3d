# Synthetic GFW-shaped effort tibble. Mirrors the columns returned by
# gfwr::gfw_ais_fishing_hours() with group_by = "GEARTYPE" so the test fixtures
# look like the real input the function receives.
make_effort <- function(rows) {
  out <- data.frame(
    Lat = rows$lat,
    Lon = rows$lon,
    `Time Range` = rows$year %||% 2022L,
    geartype = rows$geartype,
    `Vessel IDs` = rows$vessels %||% 1L,
    `Apparent Fishing Hours` = rows$hours,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
  out
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# A 5x5 study grid covering 0..5 in both dimensions, EPSG:4326. Cells are
# 1 deg square so longitude/latitude maps to integer cell indices cleanly.
make_grid <- function(res = 1, xmin = 0, xmax = 5, ymin = 0, ymax = 5,
                      crs = "EPSG:4326") {
  terra::rast(
    xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax,
    resolution = res, crs = crs
  )
}

test_that("per-gear totals round-trip from effort table to raster", {
  # Create test data
  effort <- make_effort(list(
    lat      = c(0.5, 1.5, 0.5, 2.5, 3.5),
    lon      = c(0.5, 1.5, 2.5, 3.5, 4.5),
    geartype = c("trawlers", "trawlers", "drifting_longlines",
                 "drifting_longlines", "set_gillnets"),
    hours    = c(10,  5,  3,  7,  2)
  ))
  grid <- make_grid()

  out <- gfw_effort_to_raster(effort, grid)

  totals <- terra::global(out, "sum", na.rm = TRUE)$sum
  names(totals) <- names(out)

  expect_equal(totals[["effort_trawlers"]], 15)
  expect_equal(totals[["effort_drifting_longlines"]], 10)
  expect_equal(totals[["effort_set_gillnets"]], 2)
})

test_that("output has one layer per gear class, named effort_<level>", {
  # Create test data
  effort <- make_effort(list(
    lat      = c(0.5, 1.5, 2.5),
    lon      = c(0.5, 1.5, 2.5),
    geartype = c("trawlers", "drifting_longlines", "set_gillnets"),
    hours    = c(1, 1, 1)
  ))
  grid <- make_grid()

  out <- gfw_effort_to_raster(effort, grid)

  expect_equal(terra::nlyr(out), 3)
  expect_setequal(
    names(out),
    c("effort_trawlers", "effort_drifting_longlines", "effort_set_gillnets")
  )
})

test_that("multiple records in the same cell are aggregated by `fun`", {
  # Create test data
  # Three trawler records all fall inside cell (0.5, 0.5)
  effort <- make_effort(list(
    lat      = c(0.5, 0.6, 0.7),
    lon      = c(0.5, 0.6, 0.7),
    geartype = c("trawlers", "trawlers", "trawlers"),
    hours    = c(2, 3, 5)
  ))
  grid <- make_grid()

  summed <- gfw_effort_to_raster(effort, grid, fun = "sum")
  meaned <- gfw_effort_to_raster(effort, grid, fun = "mean")

  expect_equal(terra::global(summed, "sum", na.rm = TRUE)$sum, 10)
  expect_equal(
    terra::global(meaned, "max", na.rm = TRUE)$max,
    mean(c(2, 3, 5))
  )
})

test_that("layer_by = NULL produces a single total-effort raster named 'effort'", {
  # Create test data
  effort <- make_effort(list(
    lat      = c(0.5, 1.5, 2.5),
    lon      = c(0.5, 1.5, 2.5),
    geartype = c("trawlers", "drifting_longlines", "set_gillnets"),
    hours    = c(2, 3, 5)
  ))
  grid <- make_grid()

  out <- gfw_effort_to_raster(effort, grid, layer_by = NULL)

  expect_equal(terra::nlyr(out), 1)
  expect_equal(names(out), "effort")
  expect_equal(terra::global(out, "sum", na.rm = TRUE)$sum, 10)
})

test_that("missing required columns produce an informative error", {
  # Create test data
  bad <- data.frame(
    Lat = 0.5, Lon = 0.5, geartype = "trawlers",
    stringsAsFactors = FALSE
  )
  grid <- make_grid()

  expect_error(
    gfw_effort_to_raster(bad, grid),
    "Apparent Fishing Hours"
  )
})

test_that("custom `value` and `layer_by` columns are honoured", {
  # Create test data
  effort <- data.frame(
    Lat = c(0.5, 1.5),
    Lon = c(0.5, 1.5),
    flag = c("BGD", "IND"),
    hours_total = c(4, 6),
    stringsAsFactors = FALSE
  )
  grid <- make_grid()

  out <- gfw_effort_to_raster(
    effort, grid,
    layer_by = "flag",
    value = "hours_total"
  )

  expect_setequal(names(out), c("effort_BGD", "effort_IND"))
  totals <- terra::global(out, "sum", na.rm = TRUE)$sum
  names(totals) <- names(out)
  expect_equal(totals[["effort_BGD"]], 4)
  expect_equal(totals[["effort_IND"]], 6)
})

test_that("points in EPSG:4326 are reprojected onto a non-4326 grid", {
  # Same three trawler records as round-trip test, but rasterized onto a
  # Mollweide grid. The total fishing hours should be conserved across the
  # CRS change.
  effort <- make_effort(list(
    lat      = c(0.5, 1.5, 2.5),
    lon      = c(0.5, 1.5, 2.5),
    geartype = c("trawlers", "trawlers", "trawlers"),
    hours    = c(4, 5, 6)
  ))

  moll_grid <- terra::project(make_grid(), "+proj=moll")

  out <- gfw_effort_to_raster(effort, moll_grid)

  expect_equal(terra::crs(out), terra::crs(moll_grid))
  expect_equal(
    terra::global(out, "sum", na.rm = TRUE)$sum,
    15
  )
})

# -----------------------------------------------------------------------
# build_pelagic_stack: pelagic / midwater / fixed-band gear handling.
# -----------------------------------------------------------------------

# A single-cell raster lets us reason about effort allocation without
# extracting per-cell values. Total effort = `effort_value`.
make_single_cell <- function(effort_value = 12) {
  r <- terra::rast(nrows = 1, ncols = 1, xmin = 0, xmax = 1,
                   ymin = 0, ymax = 1, crs = "EPSG:4326")
  terra::values(r) <- effort_value
  r
}

test_that("build_pelagic_stack uniform: in-band layers split effort, out-of-band are NA", {
  layer <- make_single_cell(12)
  std   <- c(0, 50, 100, 200, 500)   # in band [0, 200]: 4 of 5 depths

  out <- sharkabc3d:::build_pelagic_stack(
    layer, "gear_x",
    depth_min = 0, depth_max = 200,
    standard_depths = std, allocation = "uniform"
  )

  expect_equal(terra::nlyr(out), length(std))

  vals <- as.numeric(terra::values(out))
  names(vals) <- names(out)

  expect_equal(vals[["effort_gear_x_depth=0"]], 12 / 4)
  expect_equal(vals[["effort_gear_x_depth=50"]], 12 / 4)
  expect_equal(vals[["effort_gear_x_depth=100"]], 12 / 4)
  expect_equal(vals[["effort_gear_x_depth=200"]], 12 / 4)
  expect_true(is.na(vals[["effort_gear_x_depth=500"]]))
  expect_equal(sum(vals, na.rm = TRUE), 12)
})

test_that("build_pelagic_stack presence: every in-band layer carries the full effort", {
  layer <- make_single_cell(7)
  std   <- c(0, 100, 200, 500)        # in band [0, 200]: 3 of 4

  out <- sharkabc3d:::build_pelagic_stack(
    layer, "gear_x",
    depth_min = 0, depth_max = 200,
    standard_depths = std, allocation = "presence"
  )

  vals <- as.numeric(terra::values(out))
  names(vals) <- names(out)

  expect_equal(vals[["effort_gear_x_depth=0"]], 7)
  expect_equal(vals[["effort_gear_x_depth=100"]], 7)
  expect_equal(vals[["effort_gear_x_depth=200"]], 7)
  expect_true(is.na(vals[["effort_gear_x_depth=500"]]))
})

test_that("build_pelagic_stack errors if no standard_depths fall inside the band", {
  layer <- make_single_cell(1)
  expect_error(
    sharkabc3d:::build_pelagic_stack(
      layer, "shallow_gear",
      depth_min = 10, depth_max = 20,
      standard_depths = c(0, 50, 100), allocation = "uniform"
    ),
    "no standard_depths within band"
  )
})

test_that("build_pelagic_stack layer names follow effort_<gear>_depth=<d> convention", {
  layer <- make_single_cell(1)
  out <- sharkabc3d:::build_pelagic_stack(
    layer, "drifting_longlines",
    depth_min = 0, depth_max = 100,
    standard_depths = c(0, 50, 100), allocation = "presence"
  )
  expect_equal(
    names(out),
    c("effort_drifting_longlines_depth=0",
      "effort_drifting_longlines_depth=50",
      "effort_drifting_longlines_depth=100")
  )
})

# -----------------------------------------------------------------------
# build_benthic_stack: bathymetry-clamped per-cell band.
# -----------------------------------------------------------------------

# Three side-by-side cells, each with its own bathymetry. This lets us
# test that the per-cell band tracks bathymetry independently per cell.
make_3cell_bathy_pair <- function(bathys, efforts) {
  template <- terra::rast(nrows = 1, ncols = 3, xmin = 0, xmax = 3,
                          ymin = 0, ymax = 1, crs = "EPSG:4326")
  bathy <- template
  terra::values(bathy) <- bathys
  effort <- template
  terra::values(effort) <- efforts
  list(bathy = bathy, effort = effort,
       cell_xy = matrix(c(0.5, 0.5, 1.5, 0.5, 2.5, 0.5),
                        ncol = 2, byrow = TRUE))
}

test_that("build_benthic_stack: per-cell band tracks bathymetry across cells", {
  fix <- make_3cell_bathy_pair(
    bathys  = c(50, 100, 200),
    efforts = c(1, 1, 1)
  )
  std <- c(0, 25, 50, 75, 100, 125, 150, 175, 200)

  out <- sharkabc3d:::build_benthic_stack(
    fix$effort, "trawl",
    buffer = 50, bathymetry = fix$bathy,
    standard_depths = std, allocation = "uniform"
  )

  expect_equal(terra::nlyr(out), length(std))

  # `extract(rast, xy_matrix)` returns a data frame with one column per
  # layer and no ID column.
  cells <- as.matrix(terra::extract(out, fix$cell_xy))
  rownames(cells) <- c("c50", "c100", "c200")

  # Cell 1: bathy=50, band=[0,50] -> in-band depths {0, 25, 50}
  expect_equal(sum(!is.na(cells["c50", ])), 3)
  expect_equal(sum(cells["c50", ], na.rm = TRUE), 1)

  # Cell 2: bathy=100, band=[50,100] -> in-band depths {50, 75, 100}
  expect_equal(sum(!is.na(cells["c100", ])), 3)
  expect_equal(sum(cells["c100", ], na.rm = TRUE), 1)

  # Cell 3: bathy=200, band=[150,200] -> in-band depths {150, 175, 200}
  expect_equal(sum(!is.na(cells["c200", ])), 3)
  expect_equal(sum(cells["c200", ], na.rm = TRUE), 1)
})

test_that("build_benthic_stack: regression — bathy exactly equal to a standard_depth lands effort there", {
  # terra's `scalar <op> raster` mishandled equality (see commit fixing
  # `(d <= U)` -> `(U >= d)`). A cell with bathy == standard_depths[k]
  # must have that depth in band, with effort allocated to it.
  fix <- make_3cell_bathy_pair(bathys = c(50, NA, NA), efforts = c(2, NA, NA))
  std <- c(0, 50, 100)

  out <- sharkabc3d:::build_benthic_stack(
    fix$effort, "test", buffer = 50, bathymetry = fix$bathy,
    standard_depths = std, allocation = "uniform"
  )

  cell <- as.numeric(terra::extract(out, fix$cell_xy[1, , drop = FALSE]))
  # Band [0, 50]: depths 0 and 50 in band -> 2/2 = 1 each
  expect_equal(cell[1], 1)   # depth=0
  expect_equal(cell[2], 1)   # depth=50
  expect_true(is.na(cell[3])) # depth=100
  expect_equal(sum(cell, na.rm = TRUE), 2)
})

test_that("build_benthic_stack: presence allocation does not divide effort", {
  fix <- make_3cell_bathy_pair(bathys = c(100, NA, NA), efforts = c(4, NA, NA))
  std <- c(0, 50, 75, 100)

  out <- sharkabc3d:::build_benthic_stack(
    fix$effort, "test", buffer = 50, bathymetry = fix$bathy,
    standard_depths = std, allocation = "presence"
  )

  cell <- as.numeric(terra::extract(out, fix$cell_xy[1, , drop = FALSE]))
  # Band [50, 100]: depths 50, 75, 100 in band, full effort each
  expect_true(is.na(cell[1]))
  expect_equal(cell[2], 4)
  expect_equal(cell[3], 4)
  expect_equal(cell[4], 4)
})

test_that("build_benthic_stack errors when buffer is NA", {
  fix <- make_3cell_bathy_pair(bathys = c(100, NA, NA), efforts = c(1, NA, NA))
  expect_error(
    sharkabc3d:::build_benthic_stack(
      fix$effort, "trawl", buffer = NA, bathymetry = fix$bathy,
      standard_depths = c(0, 50, 100), allocation = "uniform"
    ),
    "benthic_buffer is NA"
  )
})

# -----------------------------------------------------------------------
# gfw_gear_depth_bands: dispatch + validation.
# -----------------------------------------------------------------------

# Build a small mixed-gear effort stack for dispatch tests.
make_mixed_effort <- function(values_per_gear) {
  template <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2,
                          ymin = 0, ymax = 2, crs = "EPSG:4326")
  layers <- lapply(names(values_per_gear), function(g) {
    r <- template
    terra::values(r) <- values_per_gear[[g]]
    names(r) <- paste0("effort_", g)
    r
  })
  list(
    template = template,
    effort   = Reduce(c, layers)
  )
}

make_lookup <- function() {
  data.frame(
    geartype = c("drifting_longlines", "trawlers", "fishing"),
    depth_min       = c(0,   NA, NA),
    depth_max       = c(200, NA, NA),
    mode            = c("pelagic", "benthic", "unknown"),
    benthic_buffer  = c(NA, 50, NA),
    stringsAsFactors = FALSE
  )
}

test_that("gfw_gear_depth_bands: fallback='drop' returns NULL for unknown gear", {
  m <- make_mixed_effort(list(fishing = c(1, 1, 1, 1)))
  bathy <- m$template; terra::values(bathy) <- c(100, 100, 100, 100)

  out <- gfw_gear_depth_bands(
    effort_layer = m$effort[["effort_fishing"]],
    gear = "fishing",
    bathymetry = bathy,
    standard_depths = c(0, 50, 100, 200),
    depth_lookup = make_lookup(),
    fallback = "drop"
  )
  expect_null(out)
})

test_that("gfw_gear_depth_bands: fallback='surface' puts unknown effort at depth=0 only", {
  m <- make_mixed_effort(list(fishing = c(2, 2, 2, 2)))
  bathy <- m$template; terra::values(bathy) <- c(100, 100, 100, 100)

  out <- gfw_gear_depth_bands(
    effort_layer = m$effort[["effort_fishing"]],
    gear = "fishing",
    bathymetry = bathy,
    standard_depths = c(0, 50, 100, 200),
    depth_lookup = make_lookup(),
    fallback = "surface"
  )

  per_layer <- terra::global(out, "sum", na.rm = TRUE)$sum
  names(per_layer) <- names(out)

  expect_equal(per_layer[["effort_fishing_depth=0"]], 4 * 2)
  expect_true(is.na(per_layer[["effort_fishing_depth=50"]]))
  expect_true(is.na(per_layer[["effort_fishing_depth=100"]]))
  expect_true(is.na(per_layer[["effort_fishing_depth=200"]]))
})

test_that("gfw_gear_depth_bands: depth_band attribute records the band used", {
  m <- make_mixed_effort(list(
    drifting_longlines = c(1, 1, 1, 1),
    trawlers           = c(1, 1, 1, 1)
  ))
  bathy <- m$template; terra::values(bathy) <- c(100, 100, 100, 100)

  pelagic_out <- gfw_gear_depth_bands(
    effort_layer = m$effort[["effort_drifting_longlines"]],
    gear = "drifting_longlines",
    bathymetry = bathy,
    standard_depths = c(0, 50, 100),
    depth_lookup = make_lookup()
  )
  benthic_out <- gfw_gear_depth_bands(
    effort_layer = m$effort[["effort_trawlers"]],
    gear = "trawlers",
    bathymetry = bathy,
    standard_depths = c(0, 50, 100),
    depth_lookup = make_lookup()
  )

  pelagic_band <- attr(pelagic_out, "depth_band")
  benthic_band <- attr(benthic_out, "depth_band")
  expect_equal(pelagic_band$geartype, "drifting_longlines")
  expect_equal(pelagic_band$depth_min_used, 0)
  expect_equal(pelagic_band$depth_max_used, 200)
  expect_equal(pelagic_band$mode, "pelagic")
  expect_equal(benthic_band$geartype, "trawlers")
  expect_true(is.na(benthic_band$depth_min_used))
  expect_equal(benthic_band$mode, "benthic")
})

test_that("gfw_gear_depth_bands errors when depth_lookup is missing required columns", {
  m <- make_mixed_effort(list(trawlers = c(1, 1, 1, 1)))
  bathy <- m$template; terra::values(bathy) <- 100
  bad <- data.frame(geartype = "trawlers", mode = "benthic")
  expect_error(
    gfw_gear_depth_bands(
      effort_layer = m$effort[["effort_trawlers"]], gear = "trawlers",
      bathymetry = bathy, standard_depths = c(0, 50, 100),
      depth_lookup = bad
    ),
    "depth_lookup is missing required columns"
  )
})

test_that("gfw_gear_depth_bands errors when the gear has no lookup entry", {
  m <- make_mixed_effort(list(mystery_gear = c(1, 1, 1, 1)))
  bathy <- m$template; terra::values(bathy) <- 100
  expect_error(
    gfw_gear_depth_bands(
      effort_layer = m$effort[["effort_mystery_gear"]], gear = "mystery_gear",
      bathymetry = bathy, standard_depths = c(0, 50, 100),
      depth_lookup = make_lookup()
    ),
    "no depth_lookup entry for gear"
  )
})

test_that("gfw_gear_depth_bands errors when bathymetry doesn't align with effort_layer", {
  m <- make_mixed_effort(list(trawlers = c(1, 1, 1, 1)))
  # Bathymetry on a different (smaller) grid
  bathy <- terra::rast(nrows = 3, ncols = 3, xmin = 0, xmax = 1,
                       ymin = 0, ymax = 1, crs = "EPSG:4326")
  terra::values(bathy) <- 100
  expect_error(
    gfw_gear_depth_bands(
      effort_layer = m$effort[["effort_trawlers"]], gear = "trawlers",
      bathymetry = bathy, standard_depths = c(0, 50, 100),
      depth_lookup = make_lookup()[2, ]
    ),
    "bathymetry must align"
  )
})

test_that("gfw_gear_depth_bands: full mass conservation across uniform pelagic + benthic", {
  m <- make_mixed_effort(list(
    drifting_longlines = c(2, 2, 2, 2),
    trawlers           = c(3, 3, 3, 3)
  ))
  bathy <- m$template; terra::values(bathy) <- c(50, 100, 150, 200)

  for (gear in c("drifting_longlines", "trawlers")) {
    orig <- terra::global(m$effort[[paste0("effort_", gear)]],
                          "sum", na.rm = TRUE)$sum
    layers_3d <- gfw_gear_depth_bands(
      effort_layer = m$effort[[paste0("effort_", gear)]],
      gear = gear,
      bathymetry = bathy,
      standard_depths = c(0, 25, 50, 75, 100, 150, 200),
      depth_lookup = make_lookup()[1:2, ],
      allocation = "uniform"
    )
    total_3d  <- sum(terra::global(layers_3d, "sum", na.rm = TRUE)$sum,
                     na.rm = TRUE)
    expect_equal(total_3d, orig, tolerance = 1e-9, info = gear)
  }
})
