# Project Spec

This document describes the intended outcomes for the sharkABC3D (SHARK and ray Abiotic Covariates in 3-Dimensions) project. SharkABC3D is an R package that is designed to facilitate the analysis of shark and ray habitat in 3D, enabling descriptions of habitat by depth and area. 

- Inputs: 
    - species ranges from IUCN Red List (2.5D, with polygon areas with depth characteristics)
    - species observations (3D, with points with X, Y, Z coordinates)
    - species distribution models (continuous 2D rasters)
    - satellite data (Copernicus, WOA datasets)
        - have depth and time layers 
    - species traits (Sharkipedia, other literature)
    - fishing pressure (gear type)
        - Global Fishing Watch (satellite imagery, 2D)
        - Fishing grounds (polygons with depth, 2.5D)

Start with what I have already implemented: 
- 2.5D analysis with polygons with depth or depth range values 
- Species ranges with depth value intersecting with WOA datasets, .nc files (Rachel's work)
    - WOA data is represented as a set of points at standard depths 
    - species ranges represented as 2D polygons with depth range (2.5D)
- Species ranges intersecting with fisheries (Alifa Haque Bangladesh)
    - species ranges represented as 2D polygons with depth range (2.5D)
    - fishing grounds represented as 2D polygons with depth range (2.5D)
    - calculate potential overlap between them as volumes (area * depth)
- Marine protected areas (Amanda's work)
    - not actually 3D analysis 
    - 2D intersection between species ranges and MPAs 
    - some MPAs have depth based restrictions, find example MPAs to represent this
- Deep sea sharks (see Brit's paper: https://www.science.org/doi/10.1126/science.ade9121)
    - vertical refuge

The idea is to create a R package that encapsulates the work across these papers, so that we can reproduce the work done and repeat depending on new data, params, etc. 

I had some grand ideas about creating a space-time cube model, combining raster and vector data. But this is probably overkill for now, point towards it as a future direction. Just refactor and implement the code used across the above 4 papers. 

## Building on existing work: 

IUCN Red List species ranges: https://www.iucnredlist.org/resources/spatial-data-download 
- species ranges as polygons

AquaMaps: 
https://www.aquamaps.org/main/home_orig.php 
https://www.biorxiv.org/content/10.1101/2025.10.19.683322v1.full.pdf 
- Species distribution models as 2D rasters 
