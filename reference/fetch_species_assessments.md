# Fetch species assessment data from IUCN Red List API

Query IUCN Red List API for species assessment data including taxonomy,
Red List category, depth limits, and assessment metadata. Retrieves the
most recent global assessment for each species.

## Usage

``` r
fetch_species_assessments(
  api_key,
  sis_ids = NULL,
  species_names = NULL,
  group_code = NULL
)
```

## Arguments

- api_key:

  Character. IUCN Red List API token. Set once per session with
  [`rredlist::rl_use_iucn()`](https://docs.ropensci.org/rredlist/reference/rl_use_iucn.html),
  or pass directly here.

- sis_ids:

  Numeric vector. SIS taxon IDs (i.e., `id_no` from IUCN shapefiles).
  Default `NULL`.

- species_names:

  Character vector. Scientific names in `"Genus species"` format.
  Default `NULL`.

- group_code:

  Character. A single comprehensive group code (e.g.,
  `"sharks_and_rays"`). Default `NULL`.

## Value

Data frame with columns: assessment_id, assessment_date, sis_id,
scientific_name, kingdom_name, phylum_name, class_name, order_name,
family_name, genus_name, species_name, subpopulation_name,
red_list_category, systems_code, upper_depth_limit, lower_depth_limit,
citation, url.

## Details

Exactly one of `sis_ids`, `species_names`, or `group_code` must be
provided.

Requires the `rredlist` package (`install.packages("rredlist")`).

## Examples

``` r
if (FALSE) { # \dontrun{
# By SIS taxon IDs (e.g., id_no column from IUCN shapefile)
assessments <- fetch_species_assessments(api_key, sis_ids = c(39332, 39385))

# By scientific names
assessments <- fetch_species_assessments(
  api_key,
  species_names = c("Sphyrna lewini", "Carcharhinus amblyrhynchos")
)

# By comprehensive group (all sharks and rays)
assessments <- fetch_species_assessments(
  api_key,
  group_code = "sharks_and_rays"
)
} # }
```
