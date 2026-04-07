#' Load species range polygons
#'
#' Load species range polygons from an IUCN Red List shapefile. Filter
#' parameters are translated into a SQL WHERE clause and passed to
#' [sf::st_read()], so only matching features are read into memory. After
#' loading, multipolygons are dissolved (unioned) per species.
#'
#' @param path Character. Path to the IUCN shapefile (.shp).
#' @param id_no Numeric vector. SIS taxon IDs to include. Default `NULL`.
#' @param sci_name Character vector. Scientific names to include. Default
#'   `NULL`.
#' @param presence Numeric vector. Presence codes to include (1 = Extant,
#'   2 = Probably Extant, etc.). Default `c(1)`.
#' @param origin Numeric vector. Origin codes to include (1 = Native,
#'   2 = Reintroduced, etc.). Default `c(1, 2)`.
#' @param seasonal Numeric vector. Seasonal codes to include (1 = Resident,
#'   2 = Breeding Season, 3 = Non-breeding Season, etc.). Default
#'   `c(1, 2, 3)`.
#' @param compiler Character vector. Compiler names to include. Default
#'   `NULL`.
#' @param yrcompiled Numeric vector. Years compiled to include. Default
#'   `NULL`.
#' @param citation Character vector. Citation strings to include. Default
#'   `NULL`.
#' @param subspecies Character vector. Subspecies names to include. Default
#'   `NULL`.
#' @param subpop Character vector. Subpopulation names to include. Default
#'   `NULL`.
#' @param source Character vector. Source values to include. Default `NULL`.
#' @param island Character vector. Island names to include. Default `NULL`.
#' @param tax_comm Character vector. Taxonomic comments to include. Default
#'   `NULL`.
#' @param dist_comm Character vector. Distribution comments to include.
#'   Default `NULL`.
#' @param generalisd Numeric vector. Generalised flag values. Default `NULL`.
#' @param legend Character vector. Legend values to include. Default `NULL`.
#' @param kingdom Character vector. Kingdom names to include. Default `NULL`.
#' @param phylum Character vector. Phylum names to include. Default `NULL`.
#' @param class Character vector. Class names to include. Default `NULL`.
#' @param order_ Character vector. Order names to include. Default `NULL`.
#' @param family Character vector. Family names to include. Default `NULL`.
#' @param genus Character vector. Genus names to include. Default `NULL`.
#' @param category Character vector. IUCN Red List category codes to include
#'   (e.g., `c("CR", "EN")`). Default `NULL`.
#' @param marine Numeric vector. Marine flag values (e.g., `c(1)`). Default
#'   `NULL`.
#' @param terrestria Numeric vector. Terrestrial flag values. Default `NULL`.
#' @param freshwater Numeric vector. Freshwater flag values. Default `NULL`.
#'
#' @returns sf object with columns: id_no, sci_name, geometry (dissolved per
#'   species).
#' @export
load_species_ranges <- function(path,
                                id_no = NULL,
                                sci_name = NULL,
                                presence = c(1),
                                origin = c(1, 2),
                                seasonal = c(1, 2, 3),
                                compiler = NULL,
                                yrcompiled = NULL,
                                citation = NULL,
                                subspecies = NULL,
                                subpop = NULL,
                                source = NULL,
                                island = NULL,
                                tax_comm = NULL,
                                dist_comm = NULL,
                                generalisd = NULL,
                                legend = NULL,
                                kingdom = NULL,
                                phylum = NULL,
                                class = NULL,
                                order_ = NULL,
                                family = NULL,
                                genus = NULL,
                                category = c("LC", "NT", "VU", "EN", "CR", "DD"),
                                marine = NULL,
                                terrestria = NULL,
                                freshwater = NULL) {
  layer_name <- sf::st_layers(path)$name[1]

  # Build SQL WHERE clause from non-NULL parameters
  clauses <- character(0)

  # Helper: quote character values for SQL
  sql_in <- function(col, vals) {
    if (is.character(vals)) {
      quoted <- paste0("'", gsub("'", "''", vals), "'")
      paste0(col, " IN (", paste(quoted, collapse = ", "), ")")
    } else {
      paste0(col, " IN (", paste(vals, collapse = ", "), ")")
    }
  }

  # Map each parameter to its shapefile column name
  filter_params <- list(
    id_no = id_no,
    sci_name = sci_name,
    presence = presence,
    origin = origin,
    seasonal = seasonal,
    compiler = compiler,
    yrcompiled = yrcompiled,
    citation = citation,
    subspecies = subspecies,
    subpop = subpop,
    source = source,
    island = island,
    tax_comm = tax_comm,
    dist_comm = dist_comm,
    generalisd = generalisd,
    legend = legend,
    kingdom = kingdom,
    phylum = phylum,
    class = class,
    order_ = order_,
    family = family,
    genus = genus,
    category = category,
    marine = marine,
    terrestria = terrestria,
    freshwater = freshwater
  )

  for (col in names(filter_params)) {
    vals <- filter_params[[col]]
    if (!is.null(vals)) {
      clauses <- c(clauses, sql_in(col, vals))
    }
  }

  if (length(clauses) > 0) {
    where <- paste(clauses, collapse = " AND ")
    sql <- paste0("SELECT * FROM \"", layer_name, "\" WHERE ", where)
    ranges <- sf::st_read(path, query = sql, quiet = TRUE)
  } else {
    ranges <- sf::st_read(path, quiet = TRUE)
  }

  if (nrow(ranges) == 0) {
    warning("No features matched the provided filters.")
    return(ranges)
  }

  # Dissolve multipolygons per species
  species_ids <- unique(ranges$id_no)
  dissolved <- lapply(species_ids, function(id) {
    sp <- ranges[ranges$id_no == id, ]
    geom <- sf::st_union(sp)
    sf::st_sf(
      id_no = id,
      sci_name = sp$sci_name[1],
      geometry = geom
    )
  })

  do.call(rbind, dissolved)
}

#' Fetch species assessment data from IUCN Red List API
#'
#' Query IUCN Red List API for species assessment data including taxonomy,
#' Red List category, depth limits, and assessment metadata. Retrieves the most
#' recent global assessment for each species.
#'
#' Exactly one of `sis_ids`, `species_names`, or `group_code` must be
#' provided.
#'
#' Requires the `rredlist` package (`install.packages("rredlist")`).
#'
#' @param api_key Character. IUCN Red List API token. Set once per session
#'   with `rredlist::rl_use_iucn()`, or pass directly here.
#' @param sis_ids Numeric vector. SIS taxon IDs (i.e., `id_no` from IUCN
#'   shapefiles). Default `NULL`.
#' @param species_names Character vector. Scientific names in `"Genus species"`
#'   format. Default `NULL`.
#' @param group_code Character. A single comprehensive group code (e.g.,
#'   `"sharks_and_rays"`). Default `NULL`.
#'
#' @returns Data frame with columns: assessment_id, assessment_date, sis_id,
#'   scientific_name, kingdom_name, phylum_name, class_name, order_name,
#'   family_name, genus_name, species_name, subpopulation_name,
#'   red_list_category, systems_code,
#'   upper_depth_limit, lower_depth_limit, citation, url.
#'
#' @examples
#' \dontrun{
#' # By SIS taxon IDs (e.g., id_no column from IUCN shapefile)
#' assessments <- fetch_species_assessments(api_key, sis_ids = c(39332, 39385))
#'
#' # By scientific names
#' assessments <- fetch_species_assessments(
#'   api_key,
#'   species_names = c("Sphyrna lewini", "Carcharhinus amblyrhynchos")
#' )
#'
#' # By comprehensive group (all sharks and rays)
#' assessments <- fetch_species_assessments(
#'   api_key,
#'   group_code = "sharks_and_rays"
#' )
#' }
#' @export
fetch_species_assessments <- function(api_key,
                                      sis_ids = NULL,
                                      species_names = NULL,
                                      group_code = NULL) {
  if (!requireNamespace("rredlist", quietly = TRUE)) {
    stop("Package 'rredlist' is required. Install with: install.packages('rredlist')")
  }

  # Validate that exactly one input is provided
  provided <- c(
    sis_ids = !is.null(sis_ids),
    species_names = !is.null(species_names),
    group_code = !is.null(group_code)
  )
  if (sum(provided) != 1) {
    stop("Exactly one of 'sis_ids', 'species_names', or 'group_code' must be provided.")
  }

  # Resolve to assessment IDs
  if (!is.null(group_code)) {
    group <- rredlist::rl_comp_groups(
      name = group_code, key = api_key, latest = TRUE, scope_code = 1
    )
    assessment_ids <- group$assessment_id
  } else if (!is.null(sis_ids)) {
    assessment_ids <- unlist(lapply(sis_ids, function(sid) {
      res <- rredlist::rl_sis_latest(id = sid, scope = "1", key = api_key)
      res$assessment_id
    }))
    assessment_ids <- assessment_ids[!is.na(assessment_ids)]
  } else {
    assessment_ids <- unlist(lapply(species_names, function(name) {
      parts <- strsplit(name, " ")[[1]]
      if (length(parts) < 2) {
        warning("Could not parse scientific name: ", name)
        return(NA)
      }
      res <- rredlist::rl_species_latest(
        genus = parts[1], species = parts[2], scope = "1", key = api_key
      )
      res$assessment_id
    }))
    assessment_ids <- assessment_ids[!is.na(assessment_ids)]
  }

  if (length(assessment_ids) == 0) {
    stop("No Global-scope assessments found for the provided input.")
  }

  # Fetch all full assessments
  a_list <- rredlist::rl_assessment_list(
    ids = assessment_ids, key = api_key
  )

  # Extract fields from each assessment into a row
  parse_assessment <- function(a) {
    # systems is a data frame with a $code column
    sys_code <- if (is.data.frame(a$systems) && nrow(a$systems) > 0) {
      paste(a$systems$code, collapse = ";")
    } else {
      NA_character_
    }

    data.frame(
      assessment_id = a$assessment_id %||% NA,
      assessment_date = a$assessment_date %||% NA,
      sis_id = a$taxon$sis_id %||% NA,
      scientific_name = a$taxon$scientific_name %||% NA,
      kingdom_name = a$taxon$kingdom_name %||% NA,
      phylum_name = a$taxon$phylum_name %||% NA,
      class_name = a$taxon$class_name %||% NA,
      order_name = a$taxon$order_name %||% NA,
      family_name = a$taxon$family_name %||% NA,
      genus_name = a$taxon$genus_name %||% NA,
      species_name = a$taxon$species_name %||% NA,
      subpopulation_name = a$taxon$subpopulation_name %||% NA_character_,
      red_list_category = a$red_list_category$code %||% NA,
      systems_code = sys_code,
      upper_depth_limit = a$supplementary_info$upper_depth_limit %||% NA,
      lower_depth_limit = a$supplementary_info$lower_depth_limit %||% NA,
      citation = a$citation %||% NA,
      url = a$url %||% NA,
      stringsAsFactors = FALSE
    )
  }

  results <- lapply(a_list, function(a) {
    tryCatch(parse_assessment(a), error = function(e) NULL)
  })

  do.call(rbind, Filter(Negate(is.null), results))
}

#' Fill missing depth values
#'
#' Fix swapped upper/lower depth values and fill NAs using genus-level means.
#' Designed for use inside [dplyr::mutate()] — returns a two-column tibble
#' (`upper_depth` and `lower_depth`) that can be unpacked with `mutate()`.
#'
#' @param upper Numeric vector. Upper (shallower) depth limit values, possibly
#'   with NAs or swapped values.
#' @param lower Numeric vector. Lower (deeper) depth limit values, possibly
#'   with NAs or swapped values.
#' @param genus Character vector. Genus names, used to compute genus-level
#'   mean depths for filling NAs.
#' @param method Character. Method for filling missing values. Currently only
#'   `"genus_mean"` is supported. Default `"genus_mean"`.
#'
#' @returns A tibble with columns `upper_depth` and `lower_depth`, suitable
#'   for use with [dplyr::mutate()].
#'
#' @examples
#' \dontrun{
#' species_info <- species_info %>%
#'   mutate(fill_missing_depths(upper_depth_limit, lower_depth_limit, genus_name))
#' }
#' @export
fill_missing_depths <- function(upper, lower, genus, method = "genus_mean") {
  if (method != "genus_mean") {
    stop("Only method = 'genus_mean' is currently supported.")
  }

  # Step 1: Fix swapped values (upper should be shallower, i.e. smaller)
  swapped <- !is.na(upper) & !is.na(lower) & upper > lower
  temp_upper <- upper
  upper[swapped] <- lower[swapped]
  lower[swapped] <- temp_upper[swapped]

  # Step 2: Compute genus-level means from non-NA values
  df <- data.frame(genus = genus, upper = upper, lower = lower,
                   stringsAsFactors = FALSE)
  genus_means <- stats::aggregate(
    cbind(upper, lower) ~ genus, data = df, FUN = mean, na.rm = TRUE,
    na.action = stats::na.pass
  )
  names(genus_means) <- c("genus", "upper_genus_mean", "lower_genus_mean")
  df <- merge(df, genus_means, by = "genus", sort = FALSE)

  # Restore original row order
  df <- df[match(genus, df$genus), ]
  # Handle duplicate genus matches — merge gives one row per unique genus,
  # so rebuild properly
  upper_genus <- genus_means$upper_genus_mean[match(genus, genus_means$genus)]
  lower_genus <- genus_means$lower_genus_mean[match(genus, genus_means$genus)]

  # Step 3: Fill NAs with genus means
  upper_filled <- ifelse(is.na(upper), upper_genus, upper)
  lower_filled <- ifelse(is.na(lower), lower_genus, lower)

  tibble::tibble(upper_depth = upper_filled, lower_depth = lower_filled)
}

#' Load bathymetry raster
#'
#' Load a GEBCO bathymetry raster from a NetCDF file using [terra::rast()].
#' Validates that the file is NetCDF format, contains an `elevation` variable,
#' and has global extent (-180 to 180, -90 to 90). Values are returned as-is
#' (GEBCO uses negative values for below sea level).
#'
#' @param file_path Character. Path to GEBCO bathymetry NetCDF file (e.g.,
#'   `"gebco_2025_sub_ice_topo/GEBCO_2025_sub_ice.nc"`).
#'
#' @returns SpatRaster with elevation values in metres.
#' @export
load_bathymetry <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }

  # Check file extension is .nc
  if (!grepl("\\.nc$", file_path, ignore.case = TRUE)) {
    stop("Expected a NetCDF (.nc) file, got: ", basename(file_path))
  }

  bathy <- terra::rast(file_path)

  # Check variable name is "elevation"
  if (!("elevation" %in% terra::varnames(bathy))) {
    stop(
      "Expected variable 'elevation' in NetCDF, found: ",
      paste(terra::varnames(bathy), collapse = ", ")
    )
  }

  # Check global extent (-180 to 180, -90 to 90)
  e <- as.vector(terra::ext(bathy))
  if (e[1] != -180 || e[2] != 180 || e[3] != -90 || e[4] != 90) {
    stop(
      "Expected global extent (-180, 180, -90, 90), got: (",
      paste(e, collapse = ", "), ")"
    )
  }

  bathy
}
