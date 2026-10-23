# Item 10 hardening verification — 2026-10-22

Scope: approved SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md §4 item 10.
Three prior concerns confirmed as coverage gaps, not production defects.

## Repairs and evidence

- Moved the original injected encoding test intact from the file-wide medfit
  version skip into test-mbco-encoding.R; no medfit-specific skip or fitting.
  Package loading still requires its imported dependencies.
- Added K=3 positive-ARIV controls for both modes: mean LR=8, stacked LR=9,
  d_S=3, r4=10, D4=3/11, nu=121/50 and independently specified F-tail p.
  These distinguish factor-two and division by K from division by two.
- Added stack-only selected-k mismatch refusals in both modes, variable
  losing-branch k success, and paired branch/k swaps preserving the result.
- Own-mode AST mutations replacing /K with /2 or omitting stacked k each
  return a valid result before failing the intended assertion. Exact single
  AST match is required; no production source is mutated.

Existing-library deterministic runner:
`/private/tmp/medfit-d1.3jrA2K/run-consumer-assertions.R`, with
`R_LIBS=/private/tmp/claude-501/medfit-lib2`, n_starts=1 and random retries
forbidden. Encoding 55 + provider 126 + acceptance 595 = **776 assertions**;
zero failures, errors or warnings. All three files lint clean; diff check clean.
The original moved block contributes 25 assertions, so net new coverage is 30.
No full stochastic suite or package installation was run.

## Independent review and dispositions

Claude plugin job 03f86a8b-b2d7-46d3-bcf5-094e0b0c13a6, standard/medium,
Sonnet (effective claude-sonnet-5-5): approve, no blockers. Read the entire
new file, removal diff, pooling/helper bodies and exact approved item 10.
Did not execute tests; provider file only grepped, runner not read. This is
static item-10 review, not independent full-suite execution or T5 approval.
13 turns, 213502 tokens, $0.2057956; no budget exhaustion.
Full result including usage/coverage:
`/private/tmp/medfit-d1.3jrA2K/ITEM10-hardening-claude-review-2026-10-22.json`.

Optional low findings are retained, not represented as required-spec blockers:

1. Positive-ARIV winning k>1 oracle would harden k-dependent formulas.
2. Fixed-mode mutants would supplement existing value/refusal assertions.
3. The moved legacy mismatch test relies on preceding tie-state mutation.
   This dependency is real and currently intentional; the new independent
   stack-only mismatch test does not share it. A future cleanup can isolate it.

One review-summary claim about the paired swap is incorrect: item10_provider
starts with k_a=1/k_b=2; swapping yields k_a=2/k_b=1. Therefore always selecting
k_a would fail the swapped case's k=1 assertion, not silently pass. This does
not invalidate the optional request for a positive winning-k>1 formula oracle.
No post-review test/source edits were made.

T5 remains **UNACCEPTED** pending qualifying real-case improper-null evidence;
D5 integration and other deferred dependency evidence remain open. Approved
spec unchanged. No installs, simulations, saved-result changes, push or merge.
Unrelated untracked research-workflow plan preserved.

## Optional-hardening closure — 21:40 MDT

Author authorized the three optional controls. Tests only; spec and production
unchanged. Winning k=2 now pins r4=5, D4=1/4, nu=144/25 and F(2,144/25) p
for K=3, mean LR=8 and d_S=3, with paired branch/k swaps in both modes.
Four private-helper mutants omit k independently from ARIV, D4, denominator
df and F numerator df. Each runs in both modes, returns MbcoMIResult and
fails the corresponding literal assertion. Fixed-mode /K and stack-k comparison
mutants likewise return valid results before the intended assertion fails.
Tie and imputation-only k mismatch now have separate self-contained providers;
there is no shared mutable rows setup between them.

Initial new-test run exposed late helper definition and an ambiguous mutation
target matching twice. Helpers moved before use; ARIV mutation targets the full
max expression, uniquely. These were harness errors, not fitter failures.
Final existing-library runner above: encoding95 + provider126 + acceptance595
= **816 passing assertions**, zero failures/errors/warnings, all three lint
files clean. No code edits after this run or Claude review; no full stochastic
suite, install or saved-result write. No production API changes needing help
or version updates.

Claude job 64bcc7d9-de05-48e4-b81e-cad4988d3a12: approve, findings empty,
low uncertainty. Standard/medium Sonnet, effective claude-sonnet-5-5; seven
turns, 150026 tokens, $0.191845, 46049 ms; no cost/turn exhaustion.
Read entire encoding file, pooling/stat helpers and exact approved item10.
Did not read the S7 class definition, LR helper definition, deterministic runner
or other dependency phases; did not execute tests. Codex execution above
already meets its suggested runner follow-up; no redundant rerun needed.
Full coverage, omissions, usage and resume metadata:
`/private/tmp/medfit-d1.3jrA2K/ITEM10-optional-claude-review-2026-10-22.json`.
All three optional findings above now addressed; no further review requested.
T5 remains **UNACCEPTED** pending real-case/D5 evidence. No push or merge.
