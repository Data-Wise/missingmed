# NOTE: what the IPW missing-data papers say, checked against the full text

| | |
|---|---|
| **Date** | 2026-10-09 |
| **Plan** | [PLAN-ipw-literature-check-2026-10-09.md](PLAN-ipw-literature-check-2026-10-09.md), tasks T1 to T5 (approved 2026-10-09) |
| **Records** | `docs/literature/ipw-missing-data.bib` (Zotero import); PDFs live in Zotero, not in the repo |
| **Status** | Reading and audit done. **No documentation has been changed.** T6 (the docs PR) is listed in section 4 and waits for the author. |

## 1. What was read, and how much

"Read in full" in the plan was not met for every paper; the depth is stated so no later reader assumes it.

| Paper | Copy | Read closely | Not read closely |
|---|---|---|---|
| Sun and Tchetgen Tchetgen (STT18) | the Zotero file is the **arXiv v2 preprint** (arXiv:1411.5310v2, 17 Oct 2015), not the published JASA text; locators below are its section and equation numbers | title page through Section 5 and the discussion (about 85% of the text) | Section 6 (the Botswana application), appendices A.1 and A.2 (proofs); read by keyword only |
| Robins and Gill (RG97) | Wiley PDF, 18 pages | Sections 1 to 6 (start), 8 and 9, Appendix I header | Section 7 (the case-control data analysis), the EM details of Section 6, appendices |
| Robins, Rotnitzky and Zhao (RRZ94) | T&F download, 22 pages (JASA pp. 846 to 866; journal page = PDF page + 844); two-column layout, read by column | abstract, Section 1, Section 6.1 with Proposition 6.1 and its commentary, Sections 7.1 and 7.2 | Sections 2 to 5 and 8 (the proofs), the appendices |
| Seaman and White (SW13) | SMMR PDF | Sections 2.3, 5.3, 6 (stabilisation), 8 (standard errors), Appendix 2; keyword search of the rest | Sections 3, 4, 7 (the application) |
| Lunceford and Davidian (LD04) | Statistics in Medicine PDF, 24 pages | Section 3.1 with equations (14) to (18); keyword search of the rest | Sections 2, 4 (simulations), 5 |

What the papers do not address is reported as "not in the paper" only where both the read sections and a keyword search found nothing. The mapping of results onto this repo's quantity (a product of two regression coefficients, `a*b`) is the repo's own extrapolation in every case and is marked so.

## 2. Answers to Q1 to Q8

Quotations are from the PDFs; `[mine]` marks reasoning that is the repo's, not a paper's.

### Q1. Is the sequential default within the randomized-monotone-missingness (RMM) class?

**Yes, as a special case, by a statement in RG97 Section 9.**

- RG97 Section 9 (Discussion, journal pp. 51 to 52) defines an "observed past missingness process", proposed by Robins et al. and independently by Mark and Gail, "under which the conditional probability the kth variable is observed depends only on the observed past; formally pr(R_k = 1 | R_1, ..., R_{k-1}, L) depends on L only through the observed past R_1 L_1, ..., R_{k-1} L_{k-1} for each k", and states: "An observed past missingness process is RMM representable."
- The sequential default is an observed-past process for one fixed order of the incomplete variables, with each factor depending on the always-observed variables only. `[mine]`: that is a special case of dependence on "the observed past".
- RG97 Section 9 goes further: a "permutation observed past" process (an order drawn at random, then an observed-past process in that order) is RMM representable, "not only is every permutation observed past missing process representable by an RMM process but the converse is true; any RMM process is representable by a permutation observed past missingness process".

### Q2. Do independent, simultaneous and monotone missingness fall under RMM, and what does not?

- **In scope** `[mine, from Q1]`: each of the gate's three mechanisms is an observed-past process in the order (M, Y) with factors depending on the always-observed variables only. Independent: P(M obs | Z) and P(Y obs | M, Z) = P(Y obs | Z). Simultaneous: P(Y obs | M obs, Z) = 1 and P(Y obs | M missing, Z) = 0. Monotone: Y observed only where M is. So all three are RMM representable by the RG97 Section 9 statement.
- **Out of scope**, RG97 Section 4 and Table I: "there exists ignorable missing data processes that are not RMM" (Summary); the paper gives a three-variable MAR process (Table I, probabilities 0 or 1) with no RMM representation and says "We have been unable to conceive of a plausible social, economic, physical or biological process that would generate MAR processes that are not RMM representable", and that "natural missing data processes that are not representable as RMM processes will be non-ignorable".

### Q3. Does the order of the sequence matter?

**Yes, in two ways, one from the papers and one from the repo's own gate.**

- **Papers.** RG97 Section 4: in an RMM process the probability of observing the next variable "can depend on the observed values of X1 and X2 and Y as well as the order in which" they were observed, so that p213 may differ from p123, and "the order of observation of the variables is not recorded for data analysis". The complete-case probability is then "the sum of the ordering-specific probabilities ... over the 3! orderings" (RG97 Section 4, journal p. 43). So a single fixed order is one point-mass case; if the true mechanism mixes orders, the complete-case probability is a sum of products, and a single-order chain can be misspecified. RG97 Section 5: a "Markov" RMM drops the dependence on the order, and "every MAR process that can be represented as an RMM process can also be represented as a Markov RMM process".
- **Monotone case, from three papers.** The ordering is fixed by the data when missingness is monotone: RRZ94 Section 7.1 (pp. 858 to 859; complete-case probability equals the product of the conditional observation probabilities, each given the previous variable observed and the observed past); SW13 Section 2.3, equations (4) and (5) (same product, each factor fitted "to only those individuals who attend visit k-1"); RG97 Section 3, equation (6); STT18 Section 3 (discrete hazards, "a series of logistic regressions ... among individuals with R <= m"). This is the repo's sequential default.
- **Why a wrong order is biased** `[mine]`. In the gate's monotone mechanism (Y observed only where M is), the reversed order has P(M obs | Y obs, Z) = 1 (degenerate) and P(Y obs | Z) = P(both observed | Z), a product of two logistics, which is not logistic. The gate measured the consequence: bias in `b` of -0.012 (reversed) against -0.001 (default order), run 2, monotone / `auxm` / 40% missing / P4 / n = 5000. The papers do not say this; the explanation and the measurement are the repo's.

### Q4. What does "coherent" mean, and is a chain of logistic factors on fully observed predictors coherent?

- **Meaning** (STT18 Abstract and Section 1): "The development of coherent missing data models to account for nonmonotone missing at random (MAR) data by inverse probability weighting (IPW) remains to date largely unresolved ... there currently is not available, a general approach to model an arbitrary nonmonotone missing data generating process strictly imposing MAR only". STT18 Section 3.1 explains why the standard route fails: a polytomous logistic model for the pattern "will often have the unintended consequence of imposing more restrictive conditions than what MAR assumption (1) strictly entails", and in general (Appendix A.1) "can at most depend on the intersection of the sets of observed variables L_(m)". RG97 Section 3 equation (7) makes the same point: the polytomous model is MAR "if and only if it is MCAR".
- **STT18's own model** (Section 3.2, equations (4) to (6)): each pattern's probability pi_m(L_(m)) is a separate logistic in the variables observed in that pattern, and the complete-case probability is 1 minus their sum. It is a different parameterization from the sequential default.
- **The sequential default and coherence.** The default conditions on the fully observed variables only, which is the "intersection" case above, so no incoherence arises. Whether a chain of logistic factors on *partially observed* predictors is coherent in general is what the papers find hard (RG97, STT18); the default does not try.

### Q5. Is the default's assumption a special case of non-monotone MAR, and what do the authors say?

**Yes, a strict special case, and the authors say so.**

- STT18 Section 3.1 (above): dependence on only "the intersection of the sets of observed variables" is "strictly stronger than the MAR assumption (1)". The default depends on exactly the fully observed variables, the intersection over all patterns.
- STT18 Section 3.2 itself uses this assumption as a pragmatic fallback for sparse patterns ("the probability of any pattern within the combined set only depends on the intersection set of variables observed for all patterns").
- SW13 Section 2.3: "The simplest missingness model uses only fully observed predictors." Appendix 2: "With non-monotone missing data, the missingness model is commonly restricted to fully observed predictors, due to the practical difficulty of fitting a Markov RMM model."
- What this means for the default: **the user is assuming that the probability of being complete depends on the fully observed variables only.** The documentation says "given the observed predictors", which a reader can take as the weaker, general MAR. It should say what is assumed (T6).

### Q6. Which result gives "estimated weights give smaller variance than known weights", and what are its conditions?

**RRZ94 Section 6.1, Proposition 6.1 (c) and (d), Corollary 6.1; supported, with conditions.**

- RRZ94 Section 6.1 (p. 855): "we can improve on the efficiency of inefficient estimators in our class by estimating the selection probabilities a(W) even when they are known." The paper's gloss after Corollary 6.1: the estimator with the estimated probability "is always more efficient" than with the known one "unless" a stated equality holds. Proposition 6.1 (c) (p. 857): the asymptotic variance with the fitted missingness model is no larger than with the known probabilities, strictly smaller unless a stated condition holds. (d): for nested correctly specified missingness models the asymptotic variance "is nonincreasing" as the parameter vector grows.
- **Conditions in the paper:** a *correctly specified* model for the missingness process; regular asymptotically linear estimators in the paper's class (regression coefficients, `g(X; a)`); the proof assumes the estimated probabilities are root-n consistent. Corollary 6.1 is stated for discrete W.
- **Extensions:** RRZ94 Sections 7.1 and 7.2 (pp. 858 to 859) state that Proposition 6.1 (with 2.3, 4.x and 6.2) remains true with the redefinitions for monotone patterns (7.1) and for arbitrary non-monotone MAR patterns (7.2), where the paper says it assumes "a correctly specified parametric model" for the pattern probabilities without saying how to build one.
- **A warning in the same section** (RRZ94 after Proposition 6.1, p. 857): "moderate overparameterization of a(psi) produces significant finite sample bias in our estimated variance ... but little bias in [the estimate] itself, suggesting that in this setting, inference (e.g., confidence intervals) should be based on bootstrap estimates". Relevant to the stacked variance's small-sample behavior; not tested here.
- **Corroboration:** STT18 equation (16) gives the variance with estimated weights as Var[Gamma - W] and says of the ordinary sandwich (equation (19)) that it is "conservative" (citing RRZ94); SW13 Section 8: "the true asymptotic SEs are actually greater when true weights are used than when they are estimated. So, ignoring uncertainty in the weights causes over-estimation of SEs, i.e. conservative inference" (citing Tsiatis 2006, reference 35, not RRZ94); LD04 Section 3.1 (journal pp. 2945 to 2946): "estimating [the propensity parameter], even if its true value is known, leads to smaller (large-sample) variance ... it is beneficial from an efficiency standpoint to estimate it anyway."
- **Not covered by any of the five papers** `[mine]`: a *product of two coefficients* (`a*b`) and the `cov(a, b)` term. The repo's second gate found stacked intervals 1% to 3% narrower, consistent in direction, no proof.

### Q7. Stabilization and truncation (SW13)

- **Stabilisation** (Section 6): it "can reduce instability of IPW estimators, but only when the mean model is correct". The numerator model needs not be correct; "If the mean model for Y given X is correct, the stabilised equations yield a consistent estimator". The repo's numerator is treatment-only (`P(R = 1 | X)`), a function of a model covariate, which is the case SW13 describes.
- **Truncation** (Section 5.3): "If the missingness model is correctly specified and the large weights arise because the predictors of missingness are highly informative, truncation may re-introduce some of the bias IPW was used to eliminate. However, when large weights are likely due to model misspecification, truncating them is a reasonable measure ... it is important to vary [the maximum] in order to verify that parameter estimates ... are not overly sensitive".

### Q8. The variance when weights are estimated, and the cap's estimation (LD04)

- **Estimated weights:** LD04 Section 3.1 treats the propensity parameters and the effect jointly as M-estimators and gives the variance with the correction, equations (14) to (16); the empirical sandwich (equations (18) to (21)) that "we have found ... to be more stable in practice". This is the construction of `.ipw_stacked_vcov()`.
- **The estimated cap: not in the paper.** A keyword search of LD04 for truncation and trimming found nothing in the sections read or searched; SW13 Section 5.3 covers truncation as a bias and sensitivity issue, not a variance one; STT18 and RRZ94 do not discuss it. The cap's estimation remains an open limit of the stacked variance, as the second gate recorded; no paper read here closes it.
- **LD04 is a causal-inference paper** (title: "Stratification and weighting via the propensity score in estimation of causal treatment effects: a comparative study"); its link to missing data is Section 2.4's remark that treatment assignment can be viewed as "missing data".

## 3. What this changes about the repo's claims

| Claim in the repo | Verdict | Basis |
|---|---|---|
| The sequential default is correct when each factor is logistic | **Supported.** For monotone patterns it is the standard result (RRZ94 7.1, SW13 2.3, RG97 3, STT18 3); the identity itself is `[mine]` | Q3 |
| The default belongs to the RMM class | **Supported** (RG97 Section 9 statement) | Q1 |
| "Given the observed predictors" (article, `technical.Rmd` 5.2) | **Too loose.** The assumption is dependence on fully observed variables only, strictly stronger than general non-monotone MAR | Q5 |
| Estimating the weights reduces the variance; the plain sandwich is conservative | **Supported with conditions** (correct missingness model; the cited setting is a regression coefficient; asymptotic) | Q6 |
| "The intervals are honest, just wider than necessary" (`technical.Rmd` 1117) | **Overstated.** True only for a correct missingness model; the repo's own first gate found shipped intervals at 0.904 to 0.921 coverage where the weights were misspecified or heavy | Q6, spec 14 |
| Stabilisation "leaves the estimate's target unchanged" (article 126) | **Needs a condition**: correct outcome (mean) model | Q7 |
| Trimming "trades a little bias for less variance" (article 141) | **Consistent**, can add the paper's advice to vary the cap | Q7 |
| The order of a list matters (article, spec) | **Supported by the repo's gate** and the monotone derivation; not stated as such in the papers | Q3 |
| The estimated cap's uncertainty is ignored | **Still true; no paper closes it** | Q8 |
| Spec section 3 describes LD04 as "variance implications of estimated weights" | Fair, but it is a causal-inference paper | Q8 |

## 4. Sentences in the repo that lean on these papers (the audit)

Found by search (`grep -rnIE "Robins|Rotnitzky|Tchetgen|Lunceford|Seaman|conservative|weights as known|estimating the weights|randomized monotone|RMM"` over `R vignettes man NEWS.md README.md _pkgdown.yml DESCRIPTION`, and over `docs/specs`): 1 user-facing hit citing a paper (`vignettes/technical.Rmd:1115`), 1 reference-list entry (`technical.Rmd:1138`), and 6 spec/note files. Each row is a proposed action for T6; none has been applied.

| # | Where | Action | Why |
|---|---|---|---|
| 1 | `vignettes/technical.Rmd:1113-1117` ("Robins, Rotnitzky and Zhao (1994) show ... The intervals are honest, just wider than necessary.") | **Reword** | State the conditions (correct missingness model, asymptotic, regression coefficients) and drop "honest" or qualify it; cite RRZ94 Section 6.1 and Proposition 6.1, with Tsiatis (2006) and Lunceford and Davidian (2004) as the general references. |
| 2 | `technical.Rmd` section 8 (references) | **Add** | RRZ94 is cited in the text and missing from the list; add RRZ94, RG97, STT18, LD04 (SW13 is there). |
| 3 | `technical.Rmd` section 5.2, sequential bullet | **Cite** | SW13 Section 2.3 equations (4) and (5); RRZ94 Section 7.1; RG97 Section 9 for the RMM membership. One clause: the order is an assumption, and a mixture of orders gives a sum of products (RG97 Section 4). |
| 4 | `technical.Rmd` section 5.2 and `ipw-weighting.Rmd` "A sequence of models, or one" | **Add one sentence** | The default assumes the probability of being complete depends on the fully observed variables only (STT18 Section 3.1; SW13 Appendix 2). |
| 5 | `ipw-weighting.Rmd:126` ("leaves the estimate's target unchanged") | **Reword** | Add "when the outcome regression is correct" (SW13 Section 6). |
| 6 | `ipw-weighting.Rmd:141` (trimming) | **Optional add** | "Vary the cap to check the result is not sensitive" (SW13 Section 5.3). |
| 7 | `ipw-weighting.Rmd:151` ("The weights are treated as known") | **Keep** | Matches SW13 Section 8. |
| 8 | `SPEC-ipw-missingness-default-2026-10-09.md` section 3, "Verification status" | **Update** | Replace "I read the abstracts" with a pointer to this note; correct the RG97 and LD04 descriptions per Q1 and Q8. |
| 9 | `SPEC-ipw-stack-hc-gate-2026-10-09.md:103-104`, `SPEC-ipw-stack-coverage-2026-10-09.md:168`, `NOTE-ipw-weight-score-stacking-2026-10-09.md:23`, `PLAN-open-items-2026-10-09.md:20` | **Keep** | Each states the direction (conditional variance reduction) that Q6 supports; add "(verified against the full text, NOTE-ipw-literature-check)" where a reader would rely on it. |
| 10 | `NEWS.md` F7 entry | **Keep** | Cites no paper; the numbers are the repo's gate. |
| 11 | `R/ipw_run.R`, chain-rule comment | **Optional** | Add "SW13 Section 2.3" as the standard reference for the monotone case. |

## 5. Open points the reading did not settle

1. **The published STT18 text** may differ from the arXiv v2 preprint used here (the Zotero file is named 2018). Citations to its equations should be checked against the published version, or cited as the arXiv preprint.
2. **Proofs and appendices were not read** (RRZ94 Sections 2 to 5 and 8, STT18 Appendix A, RG97 Section 7 and the EM appendices). Nothing in the audit depends on them, but nothing here certifies them.
3. **Tsiatis (2006)** is the source SW13 cites for the variance result and the source STT18 names for the missing-data framework; it was not read. The T6 reword may cite it as the general reference only if the author supplies it.
4. **RRZ94's overparameterization warning** (bootstrap rather than the plug-in variance when the missingness model is rich) was not tested against the stacked variance; the second gate used correctly specified, parsimonious models.
