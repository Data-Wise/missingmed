# REQUEST: P3 ruling (2026-10-26)

**ANSWERED 2026-10-26: A.** Author: "keep the gate; T5 stays blocked until a real stored case appears." Gate wording unchanged; R3 and R5 stay held. Original request follows.

Author decision needed. Nothing here amends the P3 gate; `tasks/plan.md` P3 keeps its wording until you answer.

## Question

T5 needs a qualifying pre-existing stored improper-null input. Your 2026-10-24 ruling made seeded generation nonqualifying.
Which of these stands?

- **A. Keep the gate.** T5 stays blocked until a real stored case appears. R3 (public downloads) and R5 (your project data) stay held.
- **B. Accept a documented simulated case** as the T5 real-case evidence, with its origin labeled SIMULATED. This changes the gate wording; I would amend `tasks/plan.md` and the proposal file only after your explicit words.

## Evidence on the table

- R2 (Dropbox SEM books, notebooks, Kline Roth/Sabatelli) screened 2026-10-24: none qualifies (Roth proper; Sabatelli full-model CFA Heywood).
- Simulated seed 45 (n=100, lam=0.4, a=0.4, b=0; `dev/heywood-sim.csv` in worktree `feature/heywood-null-research`, sha256 62a6984a...ca257):
  full fit proper; `a == 0` improper (negative variance M~~M); `b == 0` proper.
- Checked on medfit 0.15.0 and pinned D4 0.12.0 (`3a98bf6`): LR gaps 0, settings agree, `improper = "a"`, 2 unique warnings.
- K=5 aggregation through `mbco_d4()` and `run()`/`infer()`, `ariv` fixed and own: 8 real runs pass C1-C4; mutants M1-M3 killed.
- Not covered: stacked-fit outcome not recorded separately; one improper dataset among four clean siblings.

## My recommendation

A, unless you want B. The simulated case proves the mechanism but is exactly what the ruling excluded, so B is a policy change, not a finding.
