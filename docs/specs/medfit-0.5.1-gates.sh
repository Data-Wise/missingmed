#!/bin/sh
# Read-only release gates for medfit 0.5.1 (GitHub-only). Each gate can FAIL.
# Usage: medfit-0.5.1-gates.sh <pre|post> [medfit-checkout]
#   pre  = on origin/dev, before the release PR (version bumped, NEWS moved)
#   post = after the dev->main merge, tag and release
# Reads git objects and the GitHub API only; writes nothing.
set -u
phase=${1:?usage: $0 pre|post [medfit-dir]}
dir=${2:-$HOME/projects/r-packages/active/medfit}
cd "$dir" || exit 2
git fetch -q origin
fail=0
gate() { # gate <name> <command...>
  name=$1; shift
  if "$@" >/dev/null 2>&1; then echo "PASS  $name"; else echo "FAIL  $name"; fail=1; fi
}
ref=origin/dev; [ "$phase" = post ] && ref=origin/main

gate "DESCRIPTION Version is 0.5.1 on $ref" sh -c "git show $ref:DESCRIPTION | grep -qx 'Version: 0.5.1'"
gate "no .9000 dev suffix" sh -c "! git show $ref:DESCRIPTION | grep -q '^Version:.*9000'"
gate "NEWS top heading is 0.5.1" sh -c "git show $ref:NEWS.md | head -1 | grep -q '^# medfit 0.5.1'"
gate "NEWS 0.5.1 section holds the nobs fix (#85)" sh -c "git show $ref:NEWS.md | awk '/^# medfit 0.5.0/{exit} {print}' | grep -q 'n_obs'"
gate "NEWS 0.5.0 section no longer holds it" sh -c "! git show $ref:NEWS.md | awk '/^# medfit 0.5.0/{f=1} /^# medfit 0.4.0/{f=0} f' | grep -q 'Number of rows in data must match n_obs'"
gate "regression test file present" sh -c "git cat-file -e $ref:tests/testthat/test-extract-lavaan-weights.R"
gate "latest revdep run green (any branch)" sh -c "gh run list --workflow 'Reverse Dependency Check' --limit 1 --json conclusion --jq '.[0].conclusion' | grep -qx success"

if [ "$phase" = pre ]; then
  gate "tag v0.5.1 does not exist yet" sh -c "! git ls-remote --tags origin v0.5.1 | grep -q v0.5.1"
  gate "no failing check on dev head" sh -c "[ -z \"\$(gh api repos/Data-Wise/medfit/commits/dev/check-runs --jq '.check_runs[]|select(.conclusion==\"failure\")|.name')\" ]"
else
  gate "tag v0.5.1 exists" sh -c "git ls-remote --tags origin v0.5.1 | grep -q v0.5.1"
  gate "GitHub release v0.5.1 published" sh -c "gh release view v0.5.1 --json isDraft --jq '.isDraft' | grep -qx false"
  gate "no failing check on main head" sh -c "[ -z \"\$(gh api repos/Data-Wise/medfit/commits/main/check-runs --jq '.check_runs[]|select(.conclusion==\"failure\")|.name')\" ]"
  gate "r-universe serves 0.5.1" sh -c "curl -s https://data-wise.r-universe.dev/api/packages/medfit | grep -q '\"Version\": *\"0.5.1\"'"
fi
[ $fail -eq 0 ] && echo "ALL GATES PASS" || echo "GATES FAILED"
exit $fail
