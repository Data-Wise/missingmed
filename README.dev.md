# Development agent and CI

This repository includes a small development "agent" script and CI workflow to help with common package maintenance tasks.

Files added:

- `dev/dev_agent.R` - small CLI wrapper to run package tasks (doc, lint, test, check, build, site, status).
- `Makefile` - convenience targets that call the dev agent.
- `.github/workflows/check.yml` - GitHub Actions workflow that runs on push and PR to `main` (lint, install deps, R CMD check, tests).

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
```

Dependencies

The package does not use `renv`; dependencies install into your normal R library. Every dependency, `medfit` and `RMediation` included, is on CRAN, so a pak-based install such as `pak::local_install_deps()` resolves them without extra repositories. CI installs the same way, through `r-lib/actions/setup-r-dependencies`.

Notes

- The `dev_agent.R` script will attempt to install missing helper packages automatically. For interactive development you may prefer to install dependencies manually.
- `dev_agent.R` is intentionally small — feel free to extend it with more commands (release, covr, etc.).
