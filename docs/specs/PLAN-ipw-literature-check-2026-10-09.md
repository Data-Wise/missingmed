# PLAN: read the IPW missing-data papers in full and fix what the repo says about them

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Status** | APPROVED 2026-10-09 ("approved"; PDFs supplied through Zotero). T1 to T5 DONE: [NOTE-ipw-literature-check-2026-10-09.md](NOTE-ipw-literature-check-2026-10-09.md). T6 (the docs PR) waits for the author. |
| **Follows** | [SPEC-ipw-missingness-default-2026-10-09.md](SPEC-ipw-missingness-default-2026-10-09.md) section 3 ("Verification status": abstracts and search summaries only) |
| **Closes** | The gap left when F7 shipped (#77): the sequential default rests on a chain-rule identity that needs no citation, but the spec cites papers that were never read, and `vignettes/technical.Rmd` already carries a literature claim nobody checked. |

## 1. What is unverified today

| Paper | Where the repo uses it | What was actually read |
|---|---|---|
| Robins and Gill (1997), Stat Med 16:39 | spec section 3: "randomized monotone missingness ... some ignorable mechanisms are not of that form" | search-result abstract only |
| Sun and Tchetgen Tchetgen (2018), JASA 113:369 | spec section 3: "IPW for non-monotone MAR has been held back by the lack of coherent missingness models" | search-result abstract only |
| Robins, Rotnitzky and Zhao (1994), JASA 89:846 | spec section 3, and **`vignettes/technical.Rmd:1115`**, which states as fact that ignoring weight estimation "makes the variance conservative" and that estimating the weights "reduces variance" | the claim in `technical.Rmd` predates this work; its source was not re-read |
| Seaman and White (2013), SMMR 22:278 | `technical.Rmd` reference list (section 8); spec section 3 | not read |
| Lunceford and Davidian (2004), Stat Med 23:2937 | spec section 3 only | not read |

The user-facing article and help pages do not cite any of them. The one live exposure is the RRZ claim in `technical.Rmd`.

## 2. Questions the reading must answer

Each is a yes, no or "the paper does not say", with a page or equation locator and a quotation.

| # | Question | Paper | Why it matters |
|---|---|---|---|
| Q1 | Is the sequential (chain-rule) missingness model a member of the randomized-monotone-missingness class, or does it need an assumption RMM does not make? | RG97 | Decides whether the spec may say "consistent with the literature" or must say "an identity, outside the cited framework". |
| Q2 | Do independent, simultaneous and monotone missingness (the three mechanisms of the gate) all fall under RMM? Which ignorable mechanisms do not? | RG97 | Defines the scope the documentation may claim. |
| Q3 | Does the paper say the order of the sequence matters, or that the representation is not unique? | RG97, STT18 | The gate found a wrong order is biased under monotone missingness (-0.012); the docs say "list in the order they drop out". |
| Q4 | What does "coherent" mean for a non-monotone MAR missingness model, and is a chain of logistic factors on **fully observed** predictors coherent? | STT18 | The default conditions on fully observed variables only. General non-monotone MAR lets a factor depend on the observed values of the other incomplete variables, which the default does not do. |
| Q5 | Is the default's assumption (missingness depends only on fully observed variables) a special case of non-monotone MAR, and what do the authors say about it? | STT18 | The article currently says "given the observed predictors"; it should say exactly what is assumed. |
| Q6 | Which theorem or equation gives "estimated weights give a smaller asymptotic variance than known weights", under what conditions (a correct model, which estimator), and does it cover a regression coefficient or a product of two of them? | RRZ94 | The `technical.Rmd` claim is stated unconditionally. The repo's own gate found stacked intervals 1% to 3% narrower, which is consistent but not a proof. |
| Q7 | What do they say about stabilization and truncation? | S&W13 | `technical.Rmd` and the article describe both; confirm the description matches. |
| Q8 | What do they say about the variance when the weights are estimated, and about the cap's estimation? | L&D04 | The Codex review cited this for the stacking work; the cap uncertainty is the open limit of the stacked variance. |

## 3. Access (what I can and cannot get)

| Paper | Route | Status |
|---|---|---|
| STT18 | open: [arXiv 1411.5310](https://arxiv.org/abs/1411.5310) (v2, PDF) and [PMC6051732](https://pmc.ncbi.nlm.nih.gov/articles/PMC6051732/) | I can read it now. The arXiv v2 is the preprint; the PMC copy is the accepted manuscript, which is closer to the published text. Use PMC for locators. |
| RG97, RRZ94, S&W13, L&D04 | paywalled, or an institutional copy | Zotero search failed this session ("database is locked"), so I could not check whether you already hold them. I will not fetch paywalled text by other means. |

**Ask:** drop the four PDFs in a folder (for example `~/projects/r-packages/active/missingmed/docs/literature/`, not committed) or tell me they are in Zotero and close it so the lock clears. I read the open one first.

## 4. Tasks (each leaves the tree working; reading is read-only)

| # | Task | Acceptance | Verify |
|---|---|---|---|
| T1 | Read STT18 from PMC in full; answer Q3 to Q5 | each answer has a quotation and a locator (section, equation or page) | the note lists question, answer, quotation, locator; unanswered questions say "not in the paper" |
| T2 | Read RG97; answer Q1 to Q3 | same | same |
| T3 | Read RRZ94; answer Q6 | the theorem and its conditions are stated; the `technical.Rmd` sentence is marked supported, supported with a condition, or unsupported | same |
| T4 | Read S&W13 and L&D04; answer Q7 and Q8 | same | same |
| T5 | Write `docs/specs/NOTE-ipw-literature-check-<date>.md` with the table of questions and answers, and a list of every sentence in the repo that cites or leans on these papers, each marked keep, reword or cite | the list is produced by a search (`technical.Rmd`, the article, help pages, NEWS, spec), not from memory | the search command and its hit count are in the note |
| T6 | Documentation PR from the note: correct the `technical.Rmd` RRZ sentence if T3 requires it; add the verified references to section 8; add one sentence to the article stating the default's assumption (Q5); correct spec section 3's "Verification status" | every changed sentence traces to a note entry; markdownlint at the base file's count | CI, plus the note's keep/reword/cite list has no open rows |

T1 to T5 are one session if the PDFs are in hand (I estimate two to three hours of reading, unmeasured). T6 is a small docs PR.

## 5. What each outcome changes

| Finding | Action |
|---|---|
| Sequential model is within RMM, and the scope matches (Q1, Q2) | Cite RG97 in `technical.Rmd` section 5.2 with the scope stated. |
| Sequential model is **not** covered, or the paper warns about order | Spec section 3 says the default is justified by the chain-rule identity alone; the article's order advice cites the gate, not the paper. |
| The default assumes less than general non-monotone MAR (Q4, Q5) | State it in the article in one sentence: missingness is assumed to depend on the fully observed variables only. This is the likely outcome and a real limit of the default. |
| RRZ94 supports the variance claim only under conditions (Q6) | Reword `technical.Rmd:1115` to the conditional form; keep the gate's measured 1% to 3% as the repo's own evidence. |
| A claim is unsupported | Remove it. |

## 6. Risks

- **A paywalled paper stays unavailable.** Then its row in section 1 stays "not read", the repo cites nothing from it, and any sentence leaning on it is reworded to say what the repo's own simulations showed.
- **The papers are about different estimands.** RRZ94 and STT18 treat estimating equations and a general parameter; the repo's quantity is a product of two regression coefficients. The note must say which results transfer and which are extrapolated.
- **Reading goes into the docs unchecked.** T6 is gated on the note: no sentence is added that the note does not support.

## 7. Questions for the author (recommendation first)

1. **Provide the four PDFs now, and I read STT18 in parallel (recommended).** It unblocks T1 to T5 in one sitting; STT18 needs no access.
2. **Scope: all five papers (recommended).** The RRZ claim is the one already in a shipped vignette; dropping S&W13 and L&D04 saves about an hour but leaves two cited-but-unread references.
3. **Cite in the user-facing article, or only in `technical.Rmd`? Recommended: `technical.Rmd` only,** plus the one scope sentence in the article. The article states what the simulations showed, which is the stronger evidence for a user.
4. **Where the note lives: `docs/specs/NOTE-ipw-literature-check-*.md` on `dev` (recommended),** as with the earlier notes. PDFs stay uncommitted.
