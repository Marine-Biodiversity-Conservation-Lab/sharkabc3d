#' Extract World Ocean Atlas values from 3D volume 
#'
#' @param area SpatVector. This is the area to which the WOA raster will get 
#' cropped to. 
#' @param min_depth numeric. This is the minimum depth in metres of the volume, 
#' which will be rounded to the nearest WOA depth available. 
#' @param max_depth numeric. This is the maximum depth in metres of the volume,
#' which will be rounded to the nearest WOA depth available. 
#' @param woa_nc SpatRaster. This is the SpatRaster loaded with the terra package. 
#' This is downloaded from the World Ocean Atlas 2023 data page: 
#' https://www.ncei.noaa.gov/access/world-ocean-atlas-2023/ 
#' @param selected_field string. This is the statistical field to select, see 
#' World Ocean Atlas 2023 Product Documentation for further details: 
#' https://repository.library.noaa.gov/view/noaa/70581
#'
#' @returns SpatRaster
#' @export
#'
woa_volume_extract <- function(area, min_depth, max_depth, woa_nc, selected_field) {
  #### INPUT PARAMS CHECK ####
  # Check selected_field 
  available_fields <- c("an", "mn", "dd", "sd", "se", "oa", "gp", "sdo", "sea")
  if(!selected_field %in% available_fields) {
    stop(
      "selected_field needs to be one of the following:\n
      'an' Objectively analyzed climatology\n
      'mn' Statistical mean\n
      'dd' Number of observations\n
      'sd' Standard deviation\n
      'se' Standard error\n
      'oa' Mean minus objectively analyzed climatology\n
      'gp' Number of mean values within radius of influence\n
      'sdo' Objectively analyzed standard deviation\n
      'sea' Standard error of the analysis\n
      See World Ocean Atlas 2023: Product Documentation (https://repository.library.noaa.gov/view/noaa/70581) for more details"
    )
  }
  
  #### Select layers from woa_nc from input selected_field parameter ####
  # Create field pattern to select columns for given field
  var_abr <- woa_nc[[1]] %>% names() %>% substr(1, 2)
  field_pattern <- paste0(var_abr, selected_field, "_depth=")
  selected_names <- woa_nc %>%
    names() %>% 
    str_subset(field_pattern)
  woa_nc_selected_field <- woa_nc[[selected_names]] # create raster stack of just one field 
  # Get available depths 
  woa_depths <- selected_names %>%
    str_remove(field_pattern) %>% 
    as.numeric()
  
  #### GET DEPTH LAYERS BY DEPTH RANGE #### 
  # Get layer index of closest depth in WOA to max depth
  col_index_max_depth <- which.min(abs(woa_depths - max_depth))
  # Get layer index of closest depth in WOA to min depth
  col_index_min_depth <- which.min(abs(woa_depths - min_depth))
  # Get WOA temperature values for depths within species depth range
  relevant_depths <- woa_nc_selected_field[[col_index_min_depth:col_index_max_depth]]
  
  #### SELECT VALUES BY AREA
  woa_area_depths <- crop(relevant_depths, area, mask = T, touches = T)
  
  #### Return output ####
  woa_area_depths
}