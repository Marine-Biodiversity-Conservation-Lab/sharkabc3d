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
# Helpers for 3D-object tests: a lon/lat template grid, a GEBCO-style
# elevation raster (negative below sea level), and a polygon inside the grid.
make_template <- function(vals = NA) {
  terra::rast(nrows = 5, ncols = 5,
              xmin = 0, xmax = 5, ymin = 0, ymax = 5, 
              vals = vals, crs = "EPSG:4326")
}
make_elevation <- function(elev = -500) {
  r <- sv_template()
  terra::values(r) <- elev
  r
}
make_polygon <- function() {
  poly <- sf::st_sfc(
    sf::st_polygon(list(rbind(
      c(1, 1), c(4, 1), c(4, 4), c(1, 4), c(1, 1)
    ))),
    crs = "EPSG:4326"
  )
  sf::st_sf(geometry = poly)
}
# Helper: 2x2 footprint, cells 1-3 present, cell 4 absent. Values are
# deliberately varied (and one is 0) because only their non-NA-ness counts.
make_footprint <- function(vals = c(1, 5, 0, NA)) {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  terra::setValues(r, vals)
}
# Helper: an occupancy stack of the shape a vertical profile is handed — one
# logical layer per depth, TRUE where a cell's envelope overlaps the slab that
# depth stands for.
# Built by hand rather than through envelope_to_voxel() so profile tests do not
# depend on how occupancy is derived. Defaults give a 2x2 grid over four
# depths whose cells occupy 1, 2, 4 and 0 levels respectively; the last is the
# cell whose envelope contains none of the depths.
make_occupancy <- function(cells = list(c(TRUE, FALSE, FALSE, FALSE),
                                        c(TRUE, TRUE, FALSE, FALSE),
                                        c(TRUE, TRUE, TRUE, TRUE),
                                        c(FALSE, FALSE, FALSE, FALSE)),
                           depths = c(0, 100, 200, 300)) {
  r <- terra::rast(nrows = 2, ncols = 2, xmin = 0, xmax = 2, ymin = 0, ymax = 2)
  # A layer holds one value per cell, so the per-cell rows are read down.
  lays <- lapply(seq_along(depths), function(i) {
    terra::setValues(r, vapply(cells, function(c) c[i], logical(1)))
  })
  terra::rast(lays)
}
