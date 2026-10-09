# GRILL: mediationverse site deployment and 0.1.1 release

| | |
|---|---|
| **Target** | `Data-Wise/mediationverse` (cross-repo; every write needs per-instance permission) |
| **Date** | 2026-10-08 |
| **Status** | Done: Q1-Q3 locked; not executed |
| **Origin** | B3 of the docs audit (PRs #23, #24) |

## Evidence (codebase sweep, no question needed)

- `_pkgdown.yml` has `development: mode: auto`; pkgdown routes to `/dev/` only when `DESCRIPTION` ends in `.9000`. `dev` is `Version: 0.1.0`, so every `dev` push deploys to the site root.
- Last `gh-pages` deploy (`141ac6e`, 2026-10-09 UTC) came from `dev` commit `83e4e6d`; `/dev/` returns 404.
- `pkgdown.yaml` (push `main` and `dev`) and `altdoc.yaml` (push `main`/`master`) both deploy to `gh-pages` root with `clean: false`: a last-writer-wins race on every `main` push. Last altdoc run 2026-08-12.
- `gh-pages` still holds altdoc leftovers: `freeze.rds`, `_quarto.yml`, `custom.scss`, `quarto_website.yml`, `vignettes/`.

## Decision ledger

| # | Question | Decision | Rejected |
|---|---|---|---|
| Q1 | Stop `dev` overwriting the release site | **Set `dev` to `0.1.0.9000`**; auto mode sends `dev` to `/dev/` | main-only deploy (loses preview, hides symptom); both |
| Q2 | altdoc | **Retire**: delete `.github/workflows/altdoc.yaml` and `altdoc/`; drop `altdoc` from `Suggests` and `.Rbuildignore` (also resolves B3) | keep manual-only; keep both on separate paths |
| Q3 | Release timing | **Release 0.1.1 right after PR 1**: the `main` deploy is what corrects the live root | wait and bundle with medfit/probmed; no release |

## Execution plan (not started)

- [ ] **PR 1** (`feature/*` → `dev`, squash): `Version: 0.1.0.9000`; retire altdoc; NEWS entry. Verify: CI green; next `dev` deploy creates `/dev/`.
- [ ] **PR 2** (release prep → `dev`): `Version: 0.1.1`, NEWS section `# mediationverse 0.1.1` (carries #23, #24, `c96c955`, junk removal), `.STATUS`.
- [ ] **PR 3** `dev → main` (merge commit, no `--delete-branch`), tag `v0.1.1`, GitHub release. Verify CI on `main`; root serves 0.1.1 with missingmed; `/dev/` exists.
- [ ] After release: bump `dev` back to `0.1.1.9000`.

## Open (not decided here)

- Deleting altdoc leftovers from `gh-pages` (separate write to that branch; the release deploy keeps them via `clean: false`).
- medfit from CRAN vs GitHub in `mediationverse_update()` (deferred; see PR #23).
