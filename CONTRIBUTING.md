# Contributing to sharkabc3d

Thanks for your interest in contributing! **sharkabc3d** is an R package for
three-dimensional marine spatial analysis of sharks, rays, and chimaeras. It
grew out of several lab analyses (Bangladesh fisheries overlap, WOA
environmental extraction, deep-sea depth refuge) and is being generalised into
reusable, tested functions.

This document covers how to get set up, how we branch and coordinate, and what
a contribution needs to look like to be merged.

- [Quick orientation](#quick-orientation)
- [Development setup](#development-setup)
- [Data setup](#data-setup)
- [Branching and coordination](#branching-and-coordination)
- [What a good contribution looks like](#what-a-good-contribution-looks-like)
- [Coding conventions](#coding-conventions)
- [Testing](#testing)
- [Documentation and vignettes](#documentation-and-vignettes)
- [Known rough edges / good first issues](#known-rough-edges--good-first-issues)

---

## Quick orientation

| Path | What lives there |
| --- | --- |
| `R/` | Package functions, one file per topic: `extract.R`, `gfw.R`, `iucn_utils.R`, `load_data.R`, `plot.R`, `volume.R`, `woa.R` |
| `tests/testthat/` | One test file per `R/` file (`test-volume.R` ↔ `R/volume.R`) |
| `tests/testthat/_vcr/` | Recorded HTTP fixtures (cassettes) for IUCN Red List API tests |
| `man/` | roxygen2-generated docs — **never edit by hand** |
| `vignettes/` | Long-form worked analyses; these are the reproductions of the source papers |
| `SPEC.md` | **The design doc.** Why the package works the way it does, decisions taken, and specs for work not yet built. Not a status tracker — issues are. |
| `CLAUDE.md` | Short architecture summary (also read by AI coding assistants) |
| `renv.lock` | Pinned dependency versions |

**Read `SPEC.md` before proposing work.** Its *Architecture and conventions*
section is binding on any new code, and its *Planned work* section specifies the
things that still need building — each entry is written to seed an issue, with an
intended signature and, where one exists, a note on the prior analysis it should
be generalised from (that source material is not in this repo — ask the
maintainer).

`SPEC.md` deliberately does **not** record what is finished or who is working on
what. For that, see the [open
issues](https://github.com/Marine-Biodiversity-Conservation-Lab/sharkABC3D/issues)
and the package reference (`man/`, `?sharkabc3d`).

### The core idea, in one paragraph

All 3D analysis uses a **stacked raster** approach on `terra` + `sf`. Polygons
(species ranges, fishery footprints) are rasterized onto a GEBCO
bathymetry-derived grid by `voxelize_range()`; each cell stores presence plus
`depth_min`/`depth_max` clamped to the seafloor. Volume and volume overlap are
then per-cell raster algebra (`calc_volume()`, `calc_volume_overlap()`).
Multi-depth environmental rasters (e.g. WOA at 57 standard depths) use the
layer-naming convention `{variable}_depth={value}` (e.g. `t_an_depth=100`), and
functions such as `extract_rast_volume()` parse those names to select layers.
**Any new data-source utility must convert its input into that naming
convention.**

---

## Development setup

### 1. Requirements

- **R 4.4.3** (the version `renv.lock` was resolved against)
- Git, and system GDAL/GEOS/PROJ + NetCDF libraries for `sf` and `terra`
  - Ubuntu/Debian: `sudo apt install libgdal-dev libgeos-dev libproj-dev libudunits2-dev netcdf-bin libnetcdf-dev`
  - macOS: `brew install gdal geos proj udunits netcdf`

### 2. Clone and restore the environment

```bash
git clone https://github.com/Marine-Biodiversity-Conservation-Lab/sharkABC3D.git
cd sharkABC3D
```

```r
renv::restore()   # installs pinned dependency versions
devtools::load_all()
```

If `renv::status()` reports the project is out of sync, run `renv::restore()`
to match the lockfile. Only run `renv::snapshot()` — and commit the resulting
`renv.lock` change — when your PR **intentionally** adds or upgrades a
dependency; say so in the PR description.

Note that `gfwr` is installed from GitHub (`Remotes:` field in `DESCRIPTION`),
not CRAN.

### 3. API keys

Several functions and vignettes need credentials. Put them in `~/.Renviron`
(`usethis::edit_r_environ()`) — **never** commit them:

```
IUCN_REDLIST_KEY="..."   # https://api.iucnredlist.org/  — fetch_species_assessments()
GFW_TOKEN="..."          # https://globalfishingwatch.org/our-apis/tokens — gfwr::gfw_auth()
```

Code and tests must degrade gracefully without these: use
`testthat::skip_if(identical(Sys.getenv("IUCN_REDLIST_KEY"), ""))` or a
recorded `vcr` cassette rather than assuming a key exists.

### 4. Everyday commands

```r
devtools::load_all()          # load package for interactive work
devtools::document()          # regenerate man/ + NAMESPACE from roxygen comments
devtools::test()              # run the full test suite
testthat::test_file("tests/testthat/test-volume.R")   # one file
devtools::check()             # full R CMD check — run before opening a PR
```

---

## Data setup

**This is the biggest onboarding hurdle, so read it carefully.**

The package deliberately ships **no** large spatial data. `example_data/` is
gitignored (~1.4 GB locally) and the vignettes read from large third-party
datasets that you must download yourself:

| Dataset | Used for | Where to get it |
| --- | --- | --- |
| GEBCO 2025 sub-ice topo (`.nc`) | The common bathymetry grid for everything | <https://www.gebco.net/data_and_products/gridded_bathymetry_data/> |
| IUCN Red List `SHARKS_RAYS_CHIMAERAS` range shapefile | Species ranges | <https://www.iucnredlist.org/resources/spatial-data-download> (requires a data request) |
| Marine Regions World EEZ v12 | Study-area clipping | <https://www.marineregions.org/downloads.php> |
| World Ocean Atlas 2023 | Environmental covariates | Downloaded automatically by `woa_download()` into a cache dir; see `woa_cache_dir()` |
| Global Fishing Watch effort | Fisheries effort | Fetched via `gfwr` with `GFW_TOKEN` |
| Bangladesh participatory-mapping fishery footprints | `bangladesh-fisheries-3d-overlap` vignette | Not public — contact the maintainer |

⚠️ **Current limitation:** vignettes still contain hard-coded absolute paths
(e.g. `/home/jay/Programming_Projects/Big_Data/...`). They will not run on your
machine as-is. Until this is fixed (see
[Known rough edges](#known-rough-edges--good-first-issues)), the convention we
are moving to is a single environment variable in `~/.Renviron`:

```
SHARKABC3D_DATA="/path/to/your/big/data"
```

…with vignettes resolving paths as
`file.path(Sys.getenv("SHARKABC3D_DATA"), "gebco_2025_sub_ice_topo/GEBCO_2025_sub_ice.nc")`.
**If you touch a vignette, please convert its paths to this pattern** rather
than adding new hard-coded ones.

All vignette chunks are currently `eval = FALSE` for exactly this reason — they
are documentation of a real analysis, not something CI can reproduce. Tests, by
contrast, must run on synthetic in-memory rasters with **no external data and
no network**.

---

## Branching and coordination

We use short-lived branches off `main`, with **one issue per branch**.

### The loop

```
GitHub issue  →  self-assign  →  branch  →  PR  →  squash-merge
```

The issue is the unit of work and the record of its state; closing it via the PR
is what marks the work done. Nothing needs ticking afterwards.

1. **Find or open an issue.** Every piece of work starts as an issue. Use the
   *New function or capability* template — it covers both work already sketched
   under *Planned work* in `SPEC.md` (quote that entry in the issue) and ideas
   that aren't in `SPEC.md` at all.
2. **Claim it.** Assign yourself and comment before you start coding. This is
   how we avoid two people extracting the same function from the same
   prior analysis. If an issue has been assigned and silent for two
   weeks, it's fair game — comment first.
3. **Branch from an up-to-date `main`.**
4. **Open a PR early** (draft is fine) so others can see the area is being
   worked on.
5. **Squash-merge** and delete the branch. Reference the issue from the PR so
   it closes automatically. Update `SPEC.md` if the work changed a
   convention or departed from its spec — record the deviation under *Design
   decisions and deviations*.

`main` must always be installable — never push work-in-progress directly to it.

### Branch naming

```
<type>/<issue-number>-<short-slug>
```

There is one issue template per branch type — pick the template first and the
branch prefix follows from it.

| Type | Use for | Issue template | Example |
| --- | --- | --- | --- |
| `feat/` | A new exported function or capability | New function or capability | `feat/12-load-eez` |
| `fix/` | Bug fix in existing behaviour | Bug report | `fix/19-voxelize-dateline` |
| `vignette/` | A worked analysis | Vignette / worked analysis | `vignette/31-deep-sea-refuge` |
| `docs/` | Roxygen, README, this file, SPEC edits | Documentation | `docs/27-contributing` |
| `test/` | Tests only, no behaviour change | Test coverage | `test/23-woa-cache-coverage` |
| `refactor/` | Restructuring without behaviour change | Refactor | `refactor/34-retire-woa-nc-extract` |
| `chore/` | CI, renv, build plumbing | Chore / infrastructure | `chore/38-r-cmd-check-action` |

### Ownership map — how to avoid collisions

Work is naturally partitioned by file. Coordinate before crossing these lines,
because these files are where merge conflicts actually happen:

| Area | Files | Typical SPEC section |
| --- | --- | --- |
| Volume / voxelisation | `R/volume.R`, `R/load_data.R` | Volume calculation |
| Environmental extraction | `R/extract.R`, `R/woa.R` | Environmental extraction, WOA utilities |
| Fisheries | `R/gfw.R` | Data source utilities (GFW) |
| Species data | `R/iucn_utils.R` | Data loading and preparation |
| Geometry utilities (**unstarted, medium**) | new `R/geometry.R` | Geometry utilities |
| Plotting | `R/plot.R` | Visualization |

Two people *can* work in the same area — just make the split explicit in the
issue thread (e.g. "I'll take `fix_dateline_geometry()`, you take
`validate_geometry()`").

`NAMESPACE` is edited by nearly every PR and is the usual source of conflicts.
It is generated — if it conflicts, resolve by rerunning `devtools::document()`
rather than hand-merging. (`SPEC.md` used to conflict just as often, back when
every PR ticked a box in it. It should now change only when a convention or a
design decision changes.)

### Labels

Please apply these when you open an issue:

The templates apply a type label for you; add priority and area yourself.

- Priority: `high`, `medium`, `low` — set here, not in `SPEC.md`, so it can
  change without a commit
- Area: `area:volume`, `area:environment`, `area:fisheries`, `area:plotting`, `area:infra`
- Type (one per branch type): `bug`, `enhancement`, `documentation`, `test`,
  `refactor`, `chore`
- Extra: `good first issue`, `needs-data` (= blocked on a dataset the
  contributor may not have)

### Review and merge

- Every PR needs one approving review from a maintainer (currently
  [@JayMatsushiba](https://github.com/JayMatsushiba)) before merge.
- CI (`R CMD check`) must be green.
- Squash-merge with a message in the imperative mood, referencing the issue:
  `Add load_eez() for Marine Regions EEZ polygons (#12)`.
- Delete the branch after merging.

### Versioning

Development version is `0.0.0.9000`. Bump the fourth component in `DESCRIPTION`
(`0.0.0.9001`, …) when a PR adds or changes an exported function. We'll move to
proper `0.1.0` semantic versioning at the first tagged release.

---

## What a good contribution looks like

A PR implementing a SPEC function should include **all** of:

1. The function in the appropriate `R/*.R` file, with full roxygen2 docs
   (`@param`, `@returns`, `@examples`, `@export`).
2. Tests in the mirroring `tests/testthat/test-*.R` file, covering the happy
   path, input validation errors, and at least one edge case.
3. `devtools::document()` run, so `man/` and `NAMESPACE` are updated.
4. If the implemented signature differs from the one in *Planned work*, or the
   work established a new convention, a note under `SPEC.md` *Design decisions
   and deviations*. Deviating is fine and common — leaving it unrecorded is
   what causes trouble.
5. `devtools::check()` passing locally with no new NOTEs.

If you are generalising code from one of the prior lab analyses (named in
`SPEC.md` *Planned work*), the goal is **generalisation**, not a copy-paste: parameterise the
hard-coded species lists, study areas, and file paths, and make the function
work for any input meeting the documented contract.

---

## Coding conventions

- **Style:** tidyverse style (`styler::style_pkg()` if in doubt). Snake_case
  function and argument names.
- **Imports:** `terra` is imported wholesale; `sf`, `stringr`, `ggplot2`,
  `rlang`, `magrittr` are imported selectively via `@importFrom`. Elsewhere
  prefer explicit `pkg::fun()` calls. Add new dependencies to `DESCRIPTION`
  deliberately — this package is already heavy, so justify each one in the PR.
- **Optional dependencies:** guard with `requireNamespace("pkg", quietly =
  TRUE)` and give a clear error telling the user what to install (see
  `fetch_species_assessments()` and `rredlist`).
- **Errors:** validate inputs early and fail with an actionable message naming
  the offending argument.
- **Depth layers:** anything producing a multi-depth `SpatRaster` **must** emit
  `{variable}_depth={value}` layer names.
- **Units:** volumes in km³, areas in km², depths in metres as **positive
  numbers increasing downward** (bathymetry from GEBCO is negative below sea
  level — be explicit in your docs about which convention a given argument
  uses).
- **No side effects on load**, no `library()` calls inside `R/`, no writing to
  the user's filesystem outside `tools::R_user_dir()` (see `woa_cache_dir()`
  for the pattern).

---

## Testing

- `testthat` edition 3. One test file per source file.
- **Tests must not require external data, API keys, or network access.**
  Construct small synthetic `SpatRaster`s / `sf` objects in the test itself —
  see `tests/testthat/test-volume.R` for the pattern to copy.
- HTTP-dependent tests use `vcr` cassettes stored in `tests/testthat/_vcr/`. If
  you add an API-backed test, record a cassette rather than hitting the live
  service; scrub API keys from the recorded YAML before committing.
- Use `skip_if_not_installed()` for optional-dependency tests and
  `skip_on_cran()` for anything slow.
- Keep the suite fast. If a test needs more than a few seconds, it probably
  needs smaller synthetic inputs.

---

## Documentation and vignettes

- Roxygen2 with markdown enabled. Every exported function needs a runnable
  `@examples` block (wrap in `\dontrun{}` only if it genuinely needs external
  data or a key — prefer building a tiny synthetic example instead).
- Regenerate docs with `devtools::document()`; never hand-edit `man/`.
- `README.md` is generated from `README.Rmd` — edit the `.Rmd` and knit with
  `devtools::build_readme()`.
- Vignettes reproduce real analyses end-to-end. Keep chunks `eval = FALSE`
  unless the analysis can run from data the package can fetch itself. Structure
  them as: study question → data loading → analysis → figures → interpretation.

---

## Known rough edges / good first issues

These are real, currently-open gaps in the repo. Each is a good first
contribution — open an issue and claim it:

1. **Hard-coded data paths in vignettes.** All four vignettes point at
   `/home/jay/Programming_Projects/Big_Data/...`. Convert to the
   `SHARKABC3D_DATA` environment-variable pattern described above.
   (`area:infra`, `good first issue`)
2. **`vcr` is used but not declared.** `tests/testthat/test-iucn_utils.R` calls
   `vcr::local_cassette()`, but `vcr` is not in `DESCRIPTION` `Suggests:` and
   there is no `tests/testthat/helper-vcr.R` with `vcr::vcr_configure()`.
   Several cassettes referenced by the tests (`empty`, `multiple_inputs`,
   `three_inputs`) are also missing from `tests/testthat/_vcr/`, so those tests
   attempt live API calls and the suite hangs without a key. Adding the
   dependency, the helper, and the missing cassettes would make
   `devtools::test()` runnable for everyone. (`area:infra`, `good first issue`)
3. **No continuous integration yet.** `.github/workflows/R-CMD-check.yaml` is
   included in this repo, but it will not go green until (2) is fixed.
4. **Test coverage gaps.** `test-plot.R` has only a handful of assertions for
   five exported plotting functions; `load_bathymetry()`'s main test skips when
   `terra::writeCDF` is unavailable.
5. **Legacy function pending retirement.** `woa_nc_extract()` (in `R/woa.R`) is
   superseded by `woa_load_nc()` but is still exported (see SPEC *Planned work →
   Retirements*). Its counterpart `woa_volume_extract()` has already been removed
   in favour of `extract_rast_volume()`. Retiring `woa_nc_extract()` behind a
   deprecation warning is a clean, self-contained PR.
6. **Whole unstarted areas.** The geometry-utility, species summary-metric, and
   Copernicus entries under `SPEC.md` *Planned work* have no code at all. If you
   want a substantial, collision-free chunk of work, start there.

---

## Questions, and how to get help

- For usage, methods, or interpretation questions, open a
  [GitHub Discussion](https://github.com/Marine-Biodiversity-Conservation-Lab/sharkABC3D/discussions).
- For bugs or feature/function work, open a
  [GitHub issue](https://github.com/Marine-Biodiversity-Conservation-Lab/sharkABC3D/issues).
- For access to non-public data (the Bangladesh fishery footprints), contact
  the maintainer directly: Jay Matsushiba <hello@jmatsushiba.com>.

## Attribution

Contributors who add substantive code or analysis will be added to `Authors@R`
in `DESCRIPTION` with an appropriate role (`aut` for substantial
contributions, `ctb` otherwise). If your contribution feeds into a manuscript,
authorship will be discussed openly on the relevant issue. Please add your
ORCID when you're added.

By contributing you agree that your contributions are licensed under the
project's [GNU General Public License v3.0](LICENSE.md).
