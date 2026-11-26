# Development agent and CI

This repository includes a small development "agent" script and CI workflows to help with common package maintenance tasks.

Files added:

- `dev/dev_agent.R` - small CLI wrapper to run package tasks (doc, lint, test, check, build, site, status).
- `Makefile` - convenience targets that call the dev agent.
- `.github/workflows/check.yml` runs R CMD check on pushes to `main` and `dev` and on pull requests into `dev`.
- `.github/workflows/lint.yaml` runs lint on pushes to `main` and `dev`.
- `.github/workflows/pkgdown.yaml` builds the site on pushes to `main` and `dev`, pull requests into `dev`, published releases, and manual dispatches. Deployment requires the `main` ref or a release event.

Usage

From a shell in the package root:

```sh
# generate documentation
Rscript dev/dev_agent.R doc

# run tests
Rscript dev/dev_agent.R test

# run checks
Rscript dev/dev_agent.R check

# or use Makefile targets
make test
make check

# run the local pre-PR checks (R CMD check, lint, pkgdown reference index)
make ci
```

Dependencies

From the checkout, use the dependency combination verified in CI:

```r
options(repos = c(
  datawise = "https://data-wise.r-universe.dev",
  CRAN = "https://cloud.r-project.org"
))
pak::pak(c(
  "deps::.",
  "Data-Wise/medfit@v0.20.0",
  "S7@1.0.0",
  "RMediation@1.11.2"
))
```

On R 4.1, replace `"S7@1.0.0"` with `"S7@0.2.2"`. See the
[installation instructions](https://data-wise.github.io/missingmed/index.html#installation)
for the GitHub install.

Notes

- The `dev_agent.R` script will attempt to install missing helper packages automatically. For interactive development you may prefer to install dependencies manually.
- `dev_agent.R` is intentionally small — feel free to extend it with more commands (release, covr, etc.).
