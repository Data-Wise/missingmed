# missingmed .STATUS `worktrees:` log (archived 2026-10-16)

The `worktrees:` field below is verbatim as of dev 3f1766d, before it was archived. It records
worktree and branch cleanups from earlier sessions. Current state lives in `.STATUS`.

```text
worktrees:
  2026-10-10: REMOVED worktrees and local branches feature/mbco-mlr (PR #84, merge b2b18f2),
    feature/ipw-literature-docs (PR #78, b0dc4df) and feature/us-english-fixes (PR #83,
    eb09373). Each was clean, its tip == its merged PR's head, and the merge commit is in
    origin/dev; `git branch -d` sufficed. No remote feature/* branches remain. Later the
    same day the author deleted feature/pool-mref (PR #29, bbb89b3) and
    feature/relicense-lavaan-floor (PR #48, d1588f8) with `git branch -D` (squash merges;
    tip == PR head, merge commit in origin/dev). The leftover local branch
    worktree/quiet-meadow-d4ed (tip c751fff, an ancestor of origin/dev, no PR) was also
    deleted by the author, with its remote branch, and `git fetch --prune` cleared 23
    stale origin/feature/* tracking refs. Only local branches dev and main remain; remote
    has dev, main, gh-pages. Last worktree, app-made pensive-kare-38530a (detached HEAD
    at 898cb7b, clean, session already archived), then REMOVED with `git worktree remove
    --force`; 898cb7b stays on origin as refs/pull/29/head, and its ignored
    session-report-2026-10-07.html was copied to the main checkout's .remember/. Only
    the main checkout remains.
  2026-10-07: post-v0.5.1 cleanup. REMOVED 12 worktrees: 7 agent worktrees
    under .claude/worktrees/ and ~/.git-worktrees/missingmed/{feature-defensive-
    tests, feature-docs-site, feature-review-followups, feature-vignette-
    replication, release-0.5.1}. Each branch tip == its merged PR's head
    (#29-#36) and each merge commit is in origin/dev; dt-* branches are
    contained in feature/defensive-tests (#32); worktree-agent-* sit at
    397cd3c (on main). Untracked P1 e2e scratch (dev/e2e-p1*) was backed up
    first. The 19 local branches need `git branch -D` (squash merges; the
    branch-guard hook blocks it for the agent). Remote branches were already
    auto-deleted. pensive-kare-38530a (this session, feature/pool-mref) is
    removed by archiving the session.
  2026-10-07: app-made worktrees sad-bell-54d993 (PR #21/#23 session),
    vigilant-shaw-3f3543 (PR #22) and wonderful-curran-d50199 (PR #24)
    REMOVED; the sad-bell and vigilant-shaw sessions archived. Their local
    .token-optimizer stores are copied to the main checkout's
    .token-optimizer/backup-<name>/. Local branches deleted after checking
    each tip == its merged PR's head (or == main at adb6259):
    feature/s7-dev-article, feature/ariv-fixed, feature/ariv-rank-guard,
    feature/vignette-mbco-mi, claude/affectionate-wozniak-46b84f,
    claude/vigilant-shaw-3f3543. docs/ipw-phase1-spec deleted on origin after
    PR #26 landed its spec; local copy deleted too.
  2026-09-23: feature-narfcs-leftovers REMOVED after PR #15 merged (local tip
    == remote tip == PR head fd75a3d; merge 65f8052 on dev). Local and remote
    branch deleted.
  2026-09-23: feature-pooled-inference REMOVED after PR #14 merged (local tip
    == remote tip == PR head 6f919f3; merge 2f191d4 on dev). Local and remote
    branch deleted.
  2026-09-23: feature-drop-renv REMOVED after PR #12 merged (local tip
    16c1bce == PR head == remote tip; merge e6662a5 on dev). Local and remote
    branch deleted.
  2026-09-23: feature-narfcs-delegation REMOVED after PR #13 merged (local tip
    63e7f2f == PR head). Local branch deleted; origin/feature/narfcs-delegation
    was gone from origin too by 21:47Z.
  2026-09-23: pruned 4 dead entries whose /Users/dt/ directories no longer
    existed (feature-glm-phase, feature-mnar-sensitivity, feature-review-fixes,
    fix-minibook). Their 4 local branches and the 3 remote ones were then
    DELETED, after checking each tip: feature/glm-phase = PR #5 head (merged 24fffc3),
    feature/mnar-sensitivity = PR #6 head (b9ac0ce), feature/review-fixes =
    PR #7 head (3521d91); fix-minibook @ 240544e had no PR and its commit was
    already in dev's history. The three PR branches are restorable from their
    merged PRs.
```
