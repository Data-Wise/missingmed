# T2 provider verification receipt

Approved migration specification unchanged. Internal provider only; public wiring
is T4, option support T3, and independent historical-df controls T5.

## Executed dependency

Existing medfit 0.11.1 at `/private/tmp/claude-501/medfit-lib2/medfit`.
RemoteSha is absent; installed `R/medfit.rdb` MD5 is
`ba238e7ccb15b7c057be715a3c8f5574` (artifact identity, not a security claim).
No dependency installation, random-data generation, calibration or saved-result
changes were performed. R's stored iris and lavaan's HolzingerSwineford1939 data
were fitted. Interior-null input uses iris outcome residuals plus fixed X/C terms.

## Numerical policy

Absolute tolerance: 1e-7 **raw LR units**, inclusive, before stack/K division.
Finite LR in [-1e-7, 0) is rounded to zero with a collected warning. LR below
-1e-7 refuses inference naming the branch; pooling adds the dataset name.
There is no likelihood-relative allowance. Nonnegative LR does not certify a
global optimum.

Against the existing lavaan provider, maximum absolute branch-LR differences:

| Stored input/model | Maximum difference |
|---|---:|
| iris observed/covariate | 1.242e-10 |
| Holzinger latent mediator | 5.155e-11 |
| iris residualized interior null | 5.543e-10 |

Thus 1e-7 leaves roughly 180-fold margin above the largest inspected numerical
disagreement while remaining an absolute, small LR resolution. The null b LR
was zero under both fitters. Tests bracket -1e-7 by 1e-12 and cover non-finite
values. This is scoped empirical justification, not a universal error bound;
revalidate on dependency/optimizer changes or larger observed numerical errors.

## Completeness policy and coverage

Without a dependency ledger, nonlinear equalities, inequalities, bounds, and
equalities through defined-parameter aliases are refused before full fitting.
This also prevents nested generic-product refits from entering medfit's union
enumerator. No failure string establishes infeasibility. Duplicate products and
a seven-factor product (beyond the 64-branch enumeration limit) are refused at
this boundary rather than enumerated. Ordinary separate a/b nulls remain used.

Injected controls cover either missing/failed branch, all-failure, duplicate
rows, potentially better missing branch (1 versus survivor 9), optimizer and
covariance exceptions, dropped observations, successful minimum and S7 result,
both ARIV modes, both branch LRs and stack violations. Covariance exceptions
currently refuse inference; warning-only fits preserve likelihood summaries.
Warnings are aggregated once with dataset names. Public infer()/mbco_d4() are
still unchanged: their propagation controls belong to T4/T5.

In-memory mutations (no source edits) were killed: LR validation bypass gave
14 assertion failures/1 error; completeness bypass gave 9 failures; swapped
medfit a/b arguments gave 1 error. No mutated binding persisted.

Full package CI was not run because its suite generates random data. These
focused checks are not calibration or package-wide acceptance evidence.

## Adversarial-review repairs

Claude's fixed-string syntax counterexamples were independently reproduced.
Multi-group modifiers on untested terms and non-identifier equal() labels are
now refused before rewriting; generated labels reserve constraint/defined names.
Stored iris fits with a == b and a == 2*b + 1 match lavaan branch LRs within
1e-7 and independently show one additional null df. Affine rank checks now
refuse preconstrained tested paths (including a == 0, a == 1, and indirect
a == b; b == 0 constraints). Hard-coded k=1 is therefore checked against the
supported affine constraint geometry rather than inferred from convergence.
This does not establish identification for every singular SEM.

Collected warnings survive later refit failures. Refit improper warnings are
still surfaced as generic SEM notices; branch-specific improper attribution
remains an integration acceptance gap. T1/T2 focused tests: 35/94 passing,
zero failures/warnings/skips; provider lint clean. Unknown constraint symbols
(including pi, T and F unless actual model labels) are refused before fitting.
Reproduce mutations with the existing library (no install):

```sh
R_LIBS=/private/tmp/claude-501/medfit-lib2 Rscript dev/check-sem-provider-mutations.R
```

Current killed-mutation failures/errors: LR 15, completeness 14, labels 2.

Claude follow-up job 47e15ca0-7b80-4651-838c-9bb08ad58a2c found no T1/T2
blockers, but returned needs-attention for a low-confidence named-constant
counterexample. The symbol guard and five refusal assertions were added after
that review and verified locally, not re-reviewed. Review coverage was static:
code diff, receipt and spec sections 1-4; tests/harness only partially read,
T1 tests and spec sections 5 onward skipped. No R execution by Claude.
Uncertainty: medium. Suggested follow-up: full test reading and shared-label
coverage during later integration gates. Requested Sonnet, effective
claude-sonnet-5-5, medium effort, standard profile: 8 turns, 63.911 seconds,
152821 tokens, $0.2089233. No evidence lease, cost or turn exhaustion.
Session: ac9d67a6-cd4e-4c8b-968a-deb78eb37a9d; manual resume hint:
`claude --resume ac9d67a6-cd4e-4c8b-968a-deb78eb37a9d`.
