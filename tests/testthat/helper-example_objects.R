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
# Helpers for study_voxel tests: a lon/lat template grid, a GEBCO-style
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