#' WOA cache directory
#'
#' Returns the path to the package's persistent cache directory for downloaded
#' WOA NetCDF files. Uses [tools::R_user_dir()] so the location survives across
#' sessions and follows platform conventions.
#'
#' @returns Character. Path to cache directory (created if missing).
#' @export
woa_cache_dir <- function() {
  path <- file.path(tools::R_user_dir("sharkabc3d", which = "cache"), "woa")
  if (!dir.exists(path)) {
    dir.create(path, recursive = TRUE, showWarnings = FALSE)
  }
  path
}

#' Clear the WOA cache
#'
#' Remove all cached WOA NetCDF files.
#'
#' @param confirm Logical. Require interactive confirmation. Default `TRUE`.
#'
#' @returns Invisibly, `TRUE` on success.
#' @export
woa_cache_clear <- function(confirm = TRUE) {
  path <- woa_cache_dir()
  if (confirm && interactive()) {
    ans <- readline(sprintf("Delete all cached WOA files in %s? [y/N]: ", path))
    if (!tolower(ans) %in% c("y", "yes")) {
      message("Cancelled.")
      return(invisible(FALSE))
    }
  }
  unlink(path, recursive = TRUE, force = TRUE)
  invisible(TRUE)
}

# Internal: map variable name to WOA URL/filename components
.woa_variable_spec <- function(variable) {
  specs <- list(
    temperature       = list(dir = "temperature", code = "t", decade = "decav"),
    salinity          = list(dir = "salinity",    code = "s", decade = "decav"),
    dissolved_oxygen  = list(dir = "oxygen",      code = "o", decade = "all"),
    oxygen_saturation = list(dir = "o2sat",       code = "O", decade = "all"),
    AOU               = list(dir = "AOU",         code = "A", decade = "all"),
    nitrate           = list(dir = "nitrate",     code = "n", decade = "all"),
    phosphate         = list(dir = "phosphate",   code = "p", decade = "all"),
    silicate          = list(dir = "silicate",    code = "i", decade = "all"),
    density           = list(dir = "density",     code = "I", decade = "decav")
  )
  if (!variable %in% names(specs)) {
    stop("Unknown variable '", variable,
         "'. Supported: ", paste(names(specs), collapse = ", "))
  }
  specs[[variable]]
}

# Internal: map resolution to URL dir + filename code
.woa_resolution_spec <- function(resolution) {
  res <- as.character(resolution)
  specs <- list(
    "0.25" = list(dir = "0.25", code = "04"),
    "1"    = list(dir = "1.00", code = "01"),
    "1.00" = list(dir = "1.00", code = "01"),
    "5"    = list(dir = "5deg", code = "5d")
  )
  if (!res %in% names(specs)) {
    stop("Unknown resolution '", resolution, "'. Supported: 0.25, 1, 5.")
  }
  specs[[res]]
}

# Internal: expand period into one or more 2-digit period codes
.woa_period_codes <- function(period) {
  if (is.character(period) && length(period) == 1) {
    if (period == "annual") return("00")
    if (period == "monthly") return(sprintf("%02d", 1:12))
    if (period == "seasonal") return(sprintf("%02d", 13:16))
  }
  if (is.numeric(period)) {
    if (any(period < 0 | period > 16)) {
      stop("Numeric period must be 0 (annual), 1:12 (monthly), or 13:16 (seasonal).")
    }
    return(sprintf("%02d", period))
  }
  stop("period must be 'annual', 'monthly', 'seasonal', or a numeric 0-16.")
}

# Internal: one-time interactive consent for writing to the persistent cache.
# CRAN Repository Policy requires explicit user confirmation before writing to
# user filespace outside tempdir(). A sentinel file records consent so the
# prompt only fires once per cache directory.
.woa_cache_consent <- function(cache_dir) {
  sentinel <- file.path(cache_dir, ".consent")
  if (file.exists(sentinel)) return(invisible(TRUE))

  msg <- paste0(
    "sharkabc3d will cache downloaded WOA NetCDF files in:\n  ",
    cache_dir, "\n",
    "A full WOA set (temperature + oxygen, annual + monthly, 0.25 deg) ",
    "can exceed 10 GB.\n",
    "Pass `output_dir` to use a different location, or call ",
    "woa_cache_clear() to reclaim space later."
  )

  if (!interactive()) {
    stop(msg,
         "\nNon-interactive session: pass `output_dir` explicitly, or run ",
         "woa_download() once interactively to record consent.")
  }

  message(msg)
  ans <- readline("Proceed with caching here? [y/N]: ")
  if (!tolower(ans) %in% c("y", "yes")) {
    stop("Cache consent declined.")
  }
  file.create(sentinel)
  invisible(TRUE)
}

# Internal: fetch a single URL to `dest` via curl (no artificial timeout,
# resumable). Partial files are removed on failure so they don't masquerade
# as cached on the next call.
.woa_fetch <- function(url, dest, quiet = FALSE) {
  cleanup <- function() if (file.exists(dest)) file.remove(dest)

  tryCatch(
    curl::curl_download(url, destfile = dest, mode = "wb", quiet = quiet),
    error = function(e) {
      cleanup()
      stop("Download failed for ", url, ": ", conditionMessage(e),
           call. = FALSE)
    },
    interrupt = function(e) {
      cleanup()
      stop("Download interrupted.", call. = FALSE)
    }
  )

  if (!file.exists(dest) || file.size(dest) == 0) {
    cleanup()
    stop("Download produced empty file: ", url, call. = FALSE)
  }
  invisible(dest)
}

# Internal: HEAD request for remote file size in MB. Returns NA if the server
# doesn't report Content-Length (unusual for static NCEI files).
.woa_remote_size_mb <- function(url) {
  tryCatch({
    h <- curl::new_handle()
    curl::handle_setopt(h, nobody = TRUE)
    resp <- curl::curl_fetch_memory(url, handle = h)
    hdrs <- curl::parse_headers_list(resp$headers)
    len <- as.numeric(hdrs[["content-length"]])
    if (is.na(len) || len <= 0) NA_real_ else len / 1024^2
  }, error = function(e) NA_real_)
}

#' Download a WOA NetCDF file (with caching)
#'
#' Download World Ocean Atlas 2023 NetCDF files from the NCEI THREDDS server.
#' Files are cached in [woa_cache_dir()] (or a user-supplied `output_dir`) and
#' skipped on subsequent calls unless `force = TRUE`.
#'
#' On first use of the persistent cache in an interactive session, the function
#' prompts for consent to write to user filespace (per CRAN Repository Policy).
#' When the `curl` package is available, the estimated size of each remote
#' file is reported before downloading. A full set of WOA files can be many
#' gigabytes — supply `output_dir` to direct the cache elsewhere (HPC scratch,
#' external drive, etc.).
#'
#' @param variable Character. One of `"temperature"`, `"salinity"`,
#'   `"dissolved_oxygen"`, `"oxygen_saturation"`, `"AOU"`, `"nitrate"`,
#'   `"phosphate"`, `"silicate"`, `"density"`.
#' @param period Character or numeric. `"annual"` (default), `"monthly"`
#'   (all 12 months), `"seasonal"` (4 seasons), or a numeric vector where 0 =
#'   annual, 1:12 = monthly, 13:16 = seasonal.
#' @param resolution Character or numeric. `"0.25"` (default), `"1"`, or `"5"`
#'   degrees.
#' @param decade Character. Decade code (e.g. `"decav"`, `"all"`). Defaults to
#'   the canonical decade for the variable.
#' @param output_dir Character. Destination directory. Defaults to
#'   [woa_cache_dir()].
#' @param force Logical. If `TRUE`, re-download even if the file exists.
#'   Default `FALSE`.
#' @param quiet Logical. Suppress download progress. Default `FALSE`.
#'
#' @returns Character vector of paths to downloaded .nc files.
#' @export
woa_download <- function(variable,
                         period = "annual",
                         resolution = "0.25",
                         decade = NULL,
                         output_dir = NULL,
                         force = FALSE,
                         quiet = FALSE) {
  vspec <- .woa_variable_spec(variable)
  rspec <- .woa_resolution_spec(resolution)
  period_codes <- .woa_period_codes(period)
  if (is.null(decade)) decade <- vspec$decade

  using_default_cache <- is.null(output_dir)
  if (using_default_cache) output_dir <- woa_cache_dir()
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  }

  # Only gate consent on the persistent default cache — user-supplied paths
  # are an explicit opt-in already.
  if (using_default_cache) .woa_cache_consent(output_dir)
  base <- "https://www.ncei.noaa.gov/thredds-ocean/fileServer/woa23/DATA"

  paths <- vapply(period_codes, function(pc) {
    filename <- sprintf("woa23_%s_%s%s_%s.nc",
                        decade, vspec$code, pc, rspec$code)
    url <- sprintf("%s/%s/netcdf/%s/%s/%s",
                   base, vspec$dir, decade, rspec$dir, filename)
    dest <- file.path(output_dir, filename)

    remote_mb <- .woa_remote_size_mb(url)

    if (!force && file.exists(dest) && file.size(dest) > 0) {
      local_mb <- file.size(dest) / 1024^2
      # Re-download if remote size is known and local is clearly truncated.
      # Tolerance of 1 MB allows for filesystem reporting quirks.
      if (is.na(remote_mb) || abs(local_mb - remote_mb) < 1) {
        if (!quiet) message("Cached: ", filename)
        return(dest)
      }
      if (!quiet) {
        message(sprintf(
          "Cached file is truncated (%.1f / %.1f MB); re-downloading: %s",
          local_mb, remote_mb, filename
        ))
      }
    }

    if (!quiet) {
      size_str <- if (is.na(remote_mb)) "unknown size" else
        sprintf("%.1f MB", remote_mb)
      message("Downloading (", size_str, "): ", filename)
    }
    .woa_fetch(url, dest, quiet = quiet)
    dest
  }, character(1))

  unname(paths)
}

#' Load a WOA NetCDF file
#'
#' Load a WOA .nc file and select layers for a given statistical field. Wrapper
#' around [terra::rast()] + [woa_nc_extract()]. Returns a SpatRaster with
#' layer names already following the `{variable}_depth={value}` convention used
#' throughout this package (native to WOA NetCDFs).
#'
#' @param file_path Character. Path to a WOA .nc file.
#' @param field Character. Statistical field to select. Default `"an"`
#'   (objectively analyzed climatology). See [woa_nc_extract()] for other codes.
#'
#' @returns SpatRaster with standardized depth layer names.
#' @export
woa_load_nc <- function(file_path, field = "an") {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  r <- terra::rast(file_path)
  woa_nc_extract(r, field)
}

#' Summarise monthly WOA data across months
#'
#' Takes a directory of monthly WOA .nc files (e.g., 12 files for January to
#' December) and computes the min, max, and max-minus-min (diff) across months
#' at each depth layer. Works for any WOA variable.
#'
#' Replaces the ad-hoc loop in `data-raw/WOA.R`.
#'
#' @param monthly_dir Character. Path to directory containing monthly WOA .nc
#'   files. All `.nc` files in the directory are loaded.
#' @param field Character. Statistical field to select from each file.
#'   Default `"an"`.
#' @param files Character vector. Optional explicit list of files (overrides
#'   `monthly_dir`).
#'
#' @returns Named list of SpatRasters: `min`, `max`, `diff`. Each uses the
#'   `{variable}_depth={value}` layer naming convention.
#' @export
woa_summarise_monthly <- function(monthly_dir = NULL, field = "an",
                                  files = NULL) {
  if (is.null(files)) {
    if (is.null(monthly_dir) || !dir.exists(monthly_dir)) {
      stop("Directory not found: ", monthly_dir)
    }
    files <- list.files(monthly_dir, pattern = "\\.nc$",
                        full.names = TRUE, ignore.case = TRUE)
  }
  if (length(files) == 0) {
    stop("No .nc files found in: ", monthly_dir)
  }

  monthly <- lapply(files, function(f) woa_load_nc(f, field = field))
  depth_names <- names(monthly[[1]])

  # For each depth layer, stack that layer across all months, then reduce.
  per_depth <- lapply(depth_names, function(dn) {
    stk <- terra::rast(lapply(monthly, function(x) x[[dn]]))
    mx <- terra::app(stk, fun = "max", na.rm = TRUE)
    mn <- terra::app(stk, fun = "min", na.rm = TRUE)
    df <- mx - mn
    names(mx) <- dn
    names(mn) <- dn
    names(df) <- dn
    list(max = mx, min = mn, diff = df)
  })

  list(
    min  = terra::rast(lapply(per_depth, `[[`, "min")),
    max  = terra::rast(lapply(per_depth, `[[`, "max")),
    diff = terra::rast(lapply(per_depth, `[[`, "diff"))
  )
}

# ---------------------------------------------------------------------------
# Legacy helpers (superseded; retained for back-compat with older scripts).
# `woa_nc_extract()` is still the implementation detail behind `woa_load_nc()`.
# `woa_volume_extract()` is superseded by `extract_rast_volume()`.
# ---------------------------------------------------------------------------

#' Extract all layers of a given variable from a WOA raster
#'
#' Select layers corresponding to a given WOA statistical field (e.g. `"an"`,
#' `"mn"`) from a SpatRaster loaded from a WOA NetCDF. Used internally by
#' [woa_load_nc()].
#'
#' @param woa_nc SpatRaster loaded with [terra::rast()] from a WOA .nc file.
#'   Downloaded from <https://www.ncei.noaa.gov/access/world-ocean-atlas-2023/>.
#' @param selected_field Character. Statistical field to select. One of:
#'   `"an"` (objectively analyzed climatology), `"mn"` (statistical mean),
#'   `"dd"` (number of observations), `"sd"` (standard deviation),
#'   `"se"` (standard error), `"oa"` (mean minus climatology),
#'   `"gp"` (number of mean values within radius of influence),
#'   `"sdo"` (objectively analyzed standard deviation),
#'   `"sea"` (standard error of the analysis). See the
#'   [WOA 2023 Product Documentation](https://repository.library.noaa.gov/view/noaa/70581).
#'
#' @returns SpatRaster containing only the selected field's depth layers,
#'   using the native `{variable}_depth={value}` layer naming convention.
#' @export
woa_nc_extract <- function(woa_nc, selected_field) {
  available_fields <- c("an", "mn", "dd", "sd", "se", "oa", "gp", "sdo", "sea")
  if (!selected_field %in% available_fields) {
    stop(
      "selected_field must be one of: ",
      paste(available_fields, collapse = ", "),
      ". See https://repository.library.noaa.gov/view/noaa/70581"
    )
  }

  var_abr <- woa_nc[[1]] %>% names() %>% substr(1, 2)
  field_pattern <- paste0(var_abr, selected_field, "_depth=")
  selected_names <- woa_nc %>%
    names() %>%
    stringr::str_subset(field_pattern)
  woa_nc[[selected_names]]
}

#' Extract WOA values from a 3D volume (legacy)
#'
#' Crop a WOA SpatRaster to an area polygon and select depth layers within a
#' given depth range. Superseded by [extract_rast_volume()], which works with
#' any multi-depth SpatRaster. Retained for back-compat with older scripts.
#'
#' @param area SpatVector. Area polygon to crop the WOA raster to.
#' @param min_depth Numeric. Minimum depth (metres); rounded to nearest
#'   available WOA depth.
#' @param max_depth Numeric. Maximum depth (metres); rounded to nearest
#'   available WOA depth.
#' @param woa_nc SpatRaster loaded from a WOA .nc file.
#' @param selected_field Character. Statistical field to select — see
#'   [woa_nc_extract()].
#'
#' @returns SpatRaster cropped to `area` and filtered to the depth range.
#' @export
woa_volume_extract <- function(area, min_depth, max_depth, woa_nc,
                               selected_field) {
  var_abr <- woa_nc[[1]] %>% names() %>% substr(1, 2)
  field_pattern <- paste0(var_abr, selected_field, "_depth=")
  selected_names <- woa_nc %>%
    names() %>%
    stringr::str_subset(field_pattern)
  woa_nc_selected_field <- woa_nc[[selected_names]]

  woa_depths <- selected_names %>%
    stringr::str_remove(field_pattern) %>%
    as.numeric()

  col_index_max_depth <- which.min(abs(woa_depths - max_depth))
  col_index_min_depth <- which.min(abs(woa_depths - min_depth))
  relevant_depths <- woa_nc_selected_field[[
    col_index_min_depth:col_index_max_depth
  ]]

  terra::crop(relevant_depths, area, mask = TRUE, touches = TRUE)
}
