#!/bin/sh
# Local CI: the gates the GitHub PR workflows used to run (check.yml, lint.yaml,
# pkgdown.yaml). Run before opening a PR and quote the counts in the PR body.
# GitHub still runs the same workflows on push to main/dev.
set -e
cd "$(dirname "$0")/.."

echo "== R CMD check --as-cran (--no-manual) =="
Rscript -e 'res <- rcmdcheck::rcmdcheck(args = c("--no-manual", "--as-cran"), error_on = "never")
print(res)
n <- c(errors = length(res$errors), warnings = length(res$warnings), notes = length(res$notes))
cat("CHECK COUNTS:", paste(names(n), n, sep = "=", collapse = " "), "\n")
if (n[["errors"]] > 0 || n[["warnings"]] > 0) quit(status = 1)'

echo "== lintr on R/ =="
LINTR_ERROR_ON_LINT=true Rscript -e 'lintr::lint_package()'

echo "== pkgdown reference index =="
Rscript -e 'pkgdown::check_pkgdown()'

echo "LOCAL CI PASSED"
