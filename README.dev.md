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

Reproducible environment

If you want reproducible dependency management, initialize `renv` in the project and commit the lockfile:

```r
install.packages('renv')
renv::init()
renv::snapshot()
```

On CI we attempt to restore `renv` if a `renv.lock` file is present; otherwise the workflow installs dependencies via `remotes::install_deps()`.

Notes

- The `dev_agent.R` script will attempt to install missing helper packages automatically. For interactive development you may prefer to install dependencies manually and use `renv`.
- `dev_agent.R` is intentionally small — feel free to extend it with more commands (release, covr, etc.).
