#' Plot environmental depth profile for a species
#'
#' Plot environmental variable (e.g., temperature, dissolved oxygen) as a
#' vertical depth profile within a species range. Line plot with depth on
#' y-axis (inverted).
#'
#' @param species_name Character. Species name for the plot title.
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following the
#'   `{variable}_depth={value}` convention.
#' @param min_depth Numeric. Upper depth limit (metres).
#' @param max_depth Numeric. Lower depth limit (metres).
#'
#' @returns A ggplot object.
#' @export
plot_depth_profile <- function(species_name, rast_3d, min_depth, max_depth) {
  layer_names <- names(rast_3d)
  depths <- suppressWarnings(
    as.numeric(stringr::str_extract(layer_names, "(?<=_depth=)-?[0-9.]+"))
  )
  keep <- !is.na(depths) & depths >= min_depth & depths <= max_depth
  if (!any(keep)) {
    stop("No depth layers fall within [", min_depth, ", ", max_depth, "].")
  }
  sub <- rast_3d[[which(keep)]]

  # Per-layer summary stats across all cells
  summary_per_depth <- lapply(seq_len(terra::nlyr(sub)), function(i) {
    v <- terra::values(sub[[i]])
    data.frame(
      depth = depths[keep][i],
      mean  = suppressWarnings(mean(v, na.rm = TRUE)),
      min   = suppressWarnings(min(v, na.rm = TRUE)),
      max   = suppressWarnings(max(v, na.rm = TRUE))
    )
  })
  df <- do.call(rbind, summary_per_depth)
  df[] <- lapply(df, function(x) ifelse(is.infinite(x), NA_real_, x))

  ggplot2::ggplot(df, ggplot2::aes(x = .data$mean, y = .data$depth)) +
    ggplot2::geom_ribbon(
      ggplot2::aes(xmin = .data$min, xmax = .data$max),
      alpha = 0.2
    ) +
    ggplot2::geom_line() +
    ggplot2::geom_point() +
    ggplot2::scale_y_reverse() +
    ggplot2::labs(
      title = species_name,
      x = "Value",
      y = "Depth (m)"
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "italic")
    )
}

#' Plot species range at a specific depth layer
#'
#' Map view of a species range with environmental variable values at a specific
#' depth layer.
#'
#' @param species_range sf or SpatVector. Species range polygon.
#' @param depth Numeric. Depth (metres) at which to display environmental data.
#' @param rast_3d SpatRaster. Multi-depth raster with layer names following the
#'   `{variable}_depth={value}` convention.
#'
#' @returns A ggplot object.
#' @export
plot_range_at_depth <- function(species_range, depth, rast_3d) {
  layer_names <- names(rast_3d)
  depths <- suppressWarnings(
    as.numeric(stringr::str_extract(layer_names, "(?<=_depth=)-?[0-9.]+"))
  )
  if (all(is.na(depths))) {
    stop("No layer names match the '{variable}_depth={value}' convention.")
  }
  idx <- which.min(abs(depths - depth))
  layer <- rast_3d[[idx]]
  actual_depth <- depths[idx]

  if (inherits(species_range, "sf")) {
    range_vect <- terra::vect(species_range)
  } else {
    range_vect <- species_range
  }
  if (terra::crs(range_vect) != terra::crs(layer) && terra::crs(range_vect) != "") {
    range_vect <- terra::project(range_vect, terra::crs(layer))
  }

  cropped <- terra::crop(layer, range_vect, mask = TRUE, touches = TRUE)
  df <- as.data.frame(cropped, xy = TRUE)
  names(df)[3] <- "value"
  df <- df[!is.na(df$value), ]

  range_sf <- if (inherits(species_range, "sf")) species_range else sf::st_as_sf(range_vect)

  ggplot2::ggplot() +
    ggplot2::geom_raster(
      data = df,
      mapping = ggplot2::aes(x = .data$x, y = .data$y, fill = .data$value)
    ) +
    ggplot2::geom_sf(data = range_sf, fill = NA, colour = "black", linewidth = 0.3) +
    ggplot2::scale_fill_viridis_c(name = NULL) +
    ggplot2::coord_sf() +
    ggplot2::labs(
      subtitle = paste0("Depth: ", actual_depth, " m")
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank()
    )
}

#' Plot 3D volume overlap between two ranges
#'
#' Map view of per-cell 3D volume overlap between two rasterized ranges.
#' Cells are categorised as range A only (species), intersection (overlap),
#' or range B only (fishery), matching the visualisation style of
#' Haque et al. Requires the output of [calc_volume_overlap()].
#'
#' @param overlap_rast SpatRaster. Output of [calc_volume_overlap()], a
#'   multi-layer raster with layers: volume_a, volume_b, volume_overlap.
#' @param name_a Character. Label for range A (default `"Species"`).
#' @param name_b Character. Label for range B (default `"Fishery"`).
#'
#' @returns A ggplot object.
#' @importFrom ggplot2 ggplot aes geom_raster scale_fill_manual coord_equal
#'   theme_minimal theme labs element_text element_blank
#' @export
plot_volume_overlap <- function(overlap_rast, name_a = "Species",
                                name_b = "Fishery") {
  vol_a <- overlap_rast[["volume_a"]]
  vol_b <- overlap_rast[["volume_b"]]
  vol_ov <- overlap_rast[["volume_overlap"]]

  # Classify each cell into categories
  # 1 = A only, 2 = B only, 3 = intersection, NA = neither
  has_a <- !is.na(vol_a) & vol_a > 0
  has_b <- !is.na(vol_b) & vol_b > 0
  has_ov <- !is.na(vol_ov) & vol_ov > 0

  categ <- terra::ifel(has_ov, 3,
    terra::ifel(has_a & has_b, 3,
      terra::ifel(has_a, 1,
        terra::ifel(has_b, 2, NA))))

  # Convert to data.frame for ggplot
  df <- as.data.frame(categ, xy = TRUE)
  names(df)[3] <- "category"
  df <- df[!is.na(df$category), ]
  df$category <- factor(df$category, levels = c(1, 2, 3),
                        labels = c(name_a, name_b, "Intersect"))

  # Viridis-inspired 3-colour palette matching Figure 1:
  # dark purple = species, yellow = fishery, teal = intersection
  pal <- c(
    stats::setNames("#440154", name_a),
    stats::setNames("#fde725", name_b),
    "Intersect" = "#21918c"
  )

  ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y, fill = .data$category)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_manual(values = pal, name = NULL) +
    ggplot2::coord_equal() +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      legend.position = "bottom",
      plot.title = ggplot2::element_text(face = "italic")
    )
}

#' Plot cumulative fishing pressure on a species
#'
#' Map showing cumulative fishing pressure from all sub-fisheries on a given
#' species. Each cell is coloured by the number of fisheries whose depth range
#' overlaps the species at that location. Reproduces the per-species
#' cumulative pressure maps from Haque et al.
#'
#' @param species_rast SpatRaster. Rasterized species range from
#'   [rasterize_range()].
#' @param fishery_rasters List of SpatRasters. Rasterized fishery footprints
#'   from [rasterize_range()].
#' @param species_name Character. Optional species name for the plot title.
#'
#' @returns A ggplot object.
#' @importFrom ggplot2 ggplot aes geom_raster scale_fill_viridis_c coord_equal
#'   theme_minimal theme labs element_text element_blank
#' @export
plot_cumulative_pressure <- function(species_rast, fishery_rasters,
                                     species_name = NULL) {
  sp_presence <- !is.na(species_rast[["depth_min"]])
  sp_dmin <- species_rast[["depth_min"]]
  sp_dmax <- species_rast[["depth_max"]]

  # For each fishery, compute per-cell depth overlap with the species
  overlap_stack <- lapply(fishery_rasters, function(fr) {
    fi_presence <- !is.na(fr[["depth_min"]])
    both <- sp_presence & fi_presence

    # Depth overlap: max(min_a, min_b) < min(max_a, max_b)
    ov_min <- terra::ifel(sp_dmin > fr[["depth_min"]], sp_dmin, fr[["depth_min"]])
    ov_max <- terra::ifel(sp_dmax < fr[["depth_max"]], sp_dmax, fr[["depth_max"]])
    has_overlap <- both & (ov_max > ov_min)

    terra::ifel(has_overlap, 1, 0)
  })

  # Sum across fisheries
  count_rast <- Reduce(`+`, overlap_stack)
  # Mask to species presence and where at least one fishery overlaps
  count_rast <- terra::mask(count_rast, terra::ifel(sp_presence, 1, NA))
  count_rast <- terra::ifel(count_rast == 0, NA, count_rast)

  df <- as.data.frame(count_rast, xy = TRUE)
  names(df)[3] <- "n_fisheries"
  df <- df[!is.na(df$n_fisheries), ]

  max_n <- length(fishery_rasters)

  p <- ggplot2::ggplot(df, ggplot2::aes(x = .data$x, y = .data$y,
                                         fill = .data$n_fisheries)) +
    ggplot2::geom_raster() +
    ggplot2::scale_fill_viridis_c(
      name = "Overlapping\nFisheries",
      limits = c(0, max_n),
      breaks = seq(0, max_n, by = 1)
    ) +
    ggplot2::coord_equal() +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      plot.title = ggplot2::element_text(face = "italic")
    )

  if (!is.null(species_name)) {
    p <- p + ggplot2::labs(title = species_name)
  }

  p
}

#' Plot overlap by depth across fisheries
#'
#' Horizontal bar chart showing per-depth-bin cell counts for the species
#' range, fishery footprint, and their intersection. For a single species
#' across multiple fisheries, this recreates the depth histogram panels from
#' Haque et al. (Figure 1).
#'
#' @param species_name Character. Species name for the plot title.
#' @param fishery_names Character vector. Names of the sub-fisheries.
#' @param overlap_results Data frame or tibble with columns: species, fishery,
#'   volume_species_km3, volume_fishery_km3, volume_overlap_km3.
#'
#' @returns A ggplot object.
#' @importFrom ggplot2 ggplot aes geom_col scale_fill_manual coord_flip
#'   facet_wrap theme_minimal theme labs element_text
#' @export
plot_overlap_by_depth <- function(species_name, fishery_names,
                                  overlap_results) {
  df <- overlap_results[overlap_results$species == species_name, ]

  # Reshape to long format for grouped bar chart
  plot_df <- data.frame(
    fishery = rep(df$fishery, 3),
    component = rep(c("Species", "Fishery", "Overlap"), each = nrow(df)),
    volume_km3 = c(df$volume_species_km3, df$volume_fishery_km3,
                    df$volume_overlap_km3)
  )
  plot_df$component <- factor(plot_df$component,
                               levels = c("Species", "Fishery", "Overlap"))

  # Viridis-inspired palette matching Figure 1
  pal <- c("Species" = "#440154", "Fishery" = "#fde725",
           "Overlap" = "#21918c")

  ggplot2::ggplot(plot_df, ggplot2::aes(x = .data$fishery, y = .data$volume_km3,
                                         fill = .data$component)) +
    ggplot2::geom_col(position = "dodge") +
    ggplot2::scale_fill_manual(values = pal, name = NULL) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = species_name,
      x = NULL,
      y = expression(Volume~(km^3))
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "italic")
    )
}
