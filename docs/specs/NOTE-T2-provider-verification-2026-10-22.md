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
