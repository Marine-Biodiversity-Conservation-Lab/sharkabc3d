<!-- Title: imperative mood, referencing the issue. e.g. "Add load_eez() for Marine Regions EEZ polygons (#12)" -->

## What this does

<!-- One or two sentences. -->

Closes #

## Type

- [ ] `feat` — new exported function / capability
- [ ] `fix` — bug fix
- [ ] `test` — tests only
- [ ] `docs` — documentation
- [ ] `vignette` — worked analysis
- [ ] `refactor` / `chore`

## Checklist

<!-- Delete rows that don't apply (e.g. tests/docs for a pure chore PR). -->

- [ ] Implements/updates the corresponding **SPEC.md** item, and I ticked its checkbox
- [ ] Full roxygen2 docs on any new/changed exported function (`@param`, `@returns`, `@examples`, `@export`)
- [ ] Ran `devtools::document()` — `man/` and `NAMESPACE` are up to date
- [ ] Added/updated tests in the mirroring `tests/testthat/test-*.R`; they use synthetic data (no external files, keys, or network)
- [ ] `devtools::check()` passes locally with no new errors/warnings/NOTEs
- [ ] Multi-depth rasters (if any) use `{variable}_depth={value}` layer names
- [ ] Bumped the dev version in `DESCRIPTION` if I changed an exported function
- [ ] If I added a dependency, I ran `renv::snapshot()` and explain the need below

## Notes for reviewer

<!-- Signature deviations from SPEC, data needed to test, follow-ups, open questions. -->
