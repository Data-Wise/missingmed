#!/bin/sh
# Read-only gates for PLAN-docs-gaps-2026-10-09.md. Usage: sh docs/specs/docs-gaps-gates.sh A|B|C|all
# Each check prints PASS/FAIL; exit 1 if any FAIL. Run from the repo root.
fail=0
chk() { # chk <label> <cmd...>   (PASS when the command succeeds)
  label=$1; shift
  if "$@" >/dev/null 2>&1; then echo "PASS $label"; else echo "FAIL $label"; fail=1; fi
}
absent() { ! grep -q -i -E "$1" "$2"; }       # pattern absent from file
present() { grep -q -i -E "$1" "$2"; }        # pattern present in file
A() {
  chk "A1 mbco-mi: no 'planned' SEM line"            absent "SEM \(lavaan\) models and latent variables \(planned\)" vignettes/mbco-mi.Rmd
  chk "A1 mbco-mi: shows mbco_d4(model = )"           present "mbco_d4\([^)]*model *=|model *= *mod" vignettes/mbco-mi.Rmd
  chk "A2 faq: no 'not available for lavaan'"          absent "MBCO is not available for lavaan" vignettes/articles/faq.Rmd
  chk "A3 supported-models: no 'cannot do yet (MBCO)'" absent "cannot do yet \(MBCO\)" vignettes/articles/supported-models.Rmd
  chk "A4 choosing: MBCO line names lavaan"            present "type = \"mbco\"\).*lavaan|lavaan.*type = \"mbco\"" vignettes/articles/choosing-an-analysis.Rmd
  chk "A5 s4-migration: no 'MBCO for glm models'"      absent 'mbco.{1,3} for glm models' vignettes/articles/s4-migration.Rmd
  chk "A5 s4-migration: no 'stops for a lavaan fit'"   absent "stops for a lavaan fit" vignettes/articles/s4-migration.Rmd
  chk "A6 ?infer mentions lavaan"                      present "lavaan" man/infer.Rd
  chk "A6 ?sensitivity_mnar mentions lavaan"           present "lavaan" man/sensitivity_mnar.Rd
  chk "A6 ?MbcoMIResult mentions lavaan"               present "lavaan" man/MbcoMIResult.Rd
}
B() {
  chk "B7 faq: fit_args / dots deprecation"            present "fit_args" vignettes/articles/faq.Rmd
  chk "B7 faq: names md_dots_deprecated or 'deprecated'" present "deprecated" vignettes/articles/faq.Rmd
  chk "B8 faq: MBCO convergence entry"                 present "did not converge|non-converg" vignettes/articles/faq.Rmd
  chk "B12 getting started: lavaan pointer"            present "lavaan" vignettes/missingmed.Rmd
  chk "B9/B10 refcard article exists"                  test -f vignettes/articles/refcard.Rmd
  chk "B9/B10 refcard indexed in _pkgdown.yml"         present "articles/refcard" _pkgdown.yml
  chk "B9 matrix test exists"                          test -f tests/testthat/test-refcard-matrix.R
}
C() {
  chk "B11 mbco-mi: operating characteristics"         present "operating characteristics|conservative" vignettes/mbco-mi.Rmd
  chk "B13 cookbook article exists"                    test -f vignettes/articles/cookbook.Rmd
  chk "B13 cookbook indexed in _pkgdown.yml"           present "articles/cookbook" _pkgdown.yml
  chk "C1 CLAUDE.md names mbco_lavaan.R"               present "mbco_lavaan" CLAUDE.md
  chk "C2 cran-comments not 'first submission'"        absent "first submission" cran-comments.md
}
case "${1:-all}" in A) A;; B) B;; C) C;; all) A; B; C;; *) echo "usage: $0 A|B|C|all"; exit 2;; esac
exit $fail
