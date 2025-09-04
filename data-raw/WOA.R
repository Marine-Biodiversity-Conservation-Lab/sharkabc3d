# WOA Data Processing
library(sf)
library(terra)
library("here")
library("dplyr")
library("tidyr")
library("stringr")
library("foreach")
library("extractclimate3d")

# Create min, max, diff, mean temperature rasters for the world through full depth range
# In order to get the min, max, diff, and mean temperature for each species, I need to create some raster intermediate data products. WOA2023 provides the mean temperatures for each month of the year. In order to get the min, max, and diff temperatures, I need to summarize across the 12 months for each cell at each depth. This is what this code chunk below is doing. 
dir.create("data-processed/WOA")

output_dir <- here("data-processed/WOA/temperature")
if(!dir.exists(output_dir)) {
  dir.create(output_dir)
}
#### LOAD ####
# NetCDF raster stack
# Downloaded from: https://www.ncei.noaa.gov/thredds-ocean/catalog/woa23/DATA/temperature/netcdf/decav/0.25/catalog.html?dataset=woa23/DATA/temperature/netcdf/decav/0.25/woa23_decav_t00_04.nc

# MONTHLY MEAN (All Decades)
WOA_monthly <- list.files(here("data-raw/WOA_temp/monthly"), full.names = T) %>%
  lapply(rast) %>%
  lapply(function(x) {
    woa_nc_extract(x, "an")
  })

# get depth layer names, in order to summarise temp
depth_names <- WOA_monthly[[1]] %>% names()
# Create empty lists to append raster to
mx_depths <- c()
mn_depths <- c()
df_depths <- c()
# Loop through standard depths
depth_output <- foreach(i = 1:length(depth_names)) %do% {
  depth_name <- depth_names[i]
  start_time <- Sys.time()
  message(paste0("Working on ", depth_name, " at ", start_time))
  # for each month, get the depth temp raster
  monthly_depth <- lapply(
    WOA_monthly,
    function(x) {
      x[depth_name]
    }
  ) %>% rast()
  max_temp <- monthly_depth %>% max()
  names(max_temp) <- gsub("an", "mx", depth_name)
  mx_depths[[i]] <- max_temp
  min_temp <- monthly_depth  %>% min()
  names(min_temp) <- gsub("an", "mn", depth_name)
  mn_depths[[i]] <- min_temp
  dif_temp <- max_temp - min_temp
  names(dif_temp) <- gsub("an", "df", depth_name)
  df_depths[[i]] <- dif_temp
  
  operation_time <- Sys.time() - start_time 
  message(paste0("Finished ", depth_name, ", took ", round(operation_time, 2), " seconds"))
}
# Save Max Temp
mx_depths_rast <- rast(mx_depths) 
units(mx_depths_rast) <- "degress_celsius"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mx_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(mx_depths_rast,
         here(output_dir, "mx_depths.nc"),
         overwrite = T,
         split = T)
# Save Min Temp
mn_depths_rast <- rast(mn_depths) 
units(mn_depths_rast) <- "degress_celsius"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mn_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(mn_depths_rast,
         here(output_dir, "mn_depths.nc"),
         overwrite = T,
         split = T)
# Save Diff Temp
df_depths_rast <- rast(df_depths) 
units(df_depths_rast) <- "degress_celsius"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mx_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(df_depths_rast,
         here(output_dir, "df_depths.nc"),
         overwrite = T,
         split = T)

## Create min, max, diff, mean dissolved oxygen rasters for the world through full depth range
# In order to get the min, max, diff, and mean dissolved oxygen for each species, I need to create some raster intermediate data products. WOA2023 provides the mean dissolved oxygens for each month of the year. In order to get the min, max, and diff dissolved oxygens, I need to summarize across the 12 months for each cell at each depth. This is what this code chunk below is doing. 

output_dir <- here("data-processed/WOA/dissolved_oxygen")
if(!dir.exists(output_dir)) {
  dir.create(output_dir)
}
#### LOAD ####
# NetCDF raster stack
# Downloaded from: https://www.ncei.noaa.gov/thredds-ocean/catalog/woa23/DATA/temperature/netcdf/decav/0.25/catalog.html?dataset=woa23/DATA/temperature/netcdf/decav/0.25/woa23_decav_t00_04.nc

# MONTHLY MEAN (All Decades)
WOA_monthly <- list.files(here("data-raw/WOA_oxygen/monthly"), full.names = T) %>%
  lapply(rast) %>%
  lapply(function(x) {
    woa_nc_extract(x, "an")
  })

# get depth layer names, in order to summarise temp
depth_names <- WOA_monthly[[1]] %>% names()
# Create empty lists to append raster to
mx_depths <- c()
mn_depths <- c()
df_depths <- c()
# Loop through standard depths
depth_output <- foreach(i = 1:length(depth_names)) %do% {
  depth_name <- depth_names[i]
  start_time <- Sys.time()
  message(paste0("Working on ", depth_name, " at ", start_time))
  # for each month, get the depth temp raster
  monthly_depth <- lapply(
    WOA_monthly,
    function(x) {
      x[depth_name]
    }
  ) %>% rast()
  max_temp <- monthly_depth %>% max()
  names(max_temp) <- gsub("an", "mx", depth_name)
  mx_depths[[i]] <- max_temp
  min_temp <- monthly_depth  %>% min()
  names(min_temp) <- gsub("an", "mn", depth_name)
  mn_depths[[i]] <- min_temp
  dif_temp <- max_temp - min_temp
  names(dif_temp) <- gsub("an", "df", depth_name)
  df_depths[[i]] <- dif_temp
  
  operation_time <- Sys.time() - start_time 
  message(paste0("Finished ", depth_name, ", took ", round(operation_time, 2), " seconds"))
}
# Save Max Temp
mx_depths_rast <- rast(mx_depths) 
units(mx_depths_rast) <- "micromoles_per_kilogram"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mx_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(mx_depths_rast,
         here(output_dir, "mx_depths.nc"),
         overwrite = T,
         split = T)
# Save Min Temp
mn_depths_rast <- rast(mn_depths) 
units(mn_depths_rast) <- "micromoles_per_kilogram"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mn_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(mn_depths_rast,
         here(output_dir, "mn_depths.nc"),
         overwrite = T,
         split = T)
# Save Diff Temp
df_depths_rast <- rast(df_depths) 
units(df_depths_rast) <- "micromoles_per_kilogram"
# TODO: figure out why varnames don't get saved with writeCDF
# varnames(mx_depths_rast) <- "t_mx (Maximum monthly mean fields for sea water temperature at standard depth levels.)"
# split = T needed to keep layer names, which have depth
writeCDF(df_depths_rast,
         here(output_dir, "df_depths.nc"),
         overwrite = T,
         split = T)