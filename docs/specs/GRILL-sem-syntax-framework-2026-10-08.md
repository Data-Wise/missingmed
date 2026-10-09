# GRILL: syntax, parameter table and multilevel staging for the native SEM engine

| | |
|---|---|
| **Date** | 2026-10-08 |
| **Target** | The "syntax and intermediate table" questions raised in the framework research; extends [GRILL-native-sem-engine-nloptr-2026-10-08.md](GRILL-native-sem-engine-nloptr-2026-10-08.md) (J1-J12) and the [PLAN](PLAN-native-sem-engine-nloptr-2026-10-08.md). Numbering continues at J13. |
| **Status** | 5 branches resolved (J13-J17). The PLAN is not yet amended. |

## Evidence [V] (read from source or run this session)

- **lavaan and semopy share no parser code.** semopy first released 2018-07-27 and describes its syntax as "heavily inspired by lavaan"; its source mentions lavaan only in a `mimic_lavaan` behavior flag. lavaan's parser predates it (a 2014 comment in `lav_syntax.R`; lavaan 0.5-9 is in the CRAN archive).
- **lavaan ships three parsers** (`old`, `new`, `open`, default `open`), 3,173 lines in three files. The output is a flat table (`lhs, op, rhs, block, fixed, label, start, mod.idx`) with `modifiers` and `constraints` attributes; `:=` and `==` go in `constraints`, not in table rows.
- **lavaan's open parser is configurable:** exported `lav_parse_options(pkgname, operators, modifiers, groupings)`. Operators: `=~ <~ ~*~ ~~ ~ |~ == < > := : | % :~`. Modifiers: `efa fixed label start lower upper rv equal`. Groupings: `group level class block`.
- **semopy's parser** is 204 lines, line-oriented regex; output is a nested dict (operator, left side, right side, multiplier) plus a dict of directive lines (`START()`, `BOUND()`, `CONSTRAINT()`, `DEFINE()`). It accepts any operator token (it parsed `:=`). semopy has `ModelEffects`/kernel random effects, not clustered multilevel SEM.
- lavaan two-level syntax works in 0.7-3 (`level: 1` / `level: 2` blocks, 60 clusters, 0.17 s fit).

## Decisions

| # | Question | Decision | Consequence recorded |
|---|---|---|---|
| J13 | Parser | **Own subset parser; lavaan's `lavParseModelString()` is the test oracle** | Independent at runtime; we own the grammar subset and must freeze and document it (lavaan changed parsers three times and added `:~` in 0.7-3). |
| J14 | Intermediate table | **Own table, with converters to both lavaan's ParTable and RAM** (the author chose this over the recommended "lavaan ParTable subset") | Three representations to keep consistent (own table, ParTable, RAM). Needs converter tests (round trip against `lavaanify()`) and a plan task; the table is designed for our needs, and the converters carry the interop cost. |
| J15 | v0 syntax features | **All four groups:** core (`=~ ~ ~~`) with labels, fixed values and `:=`; `==`/`<`/`>` constraints; `start`/`lower`/`upper` modifiers; **comma shorthand and CONSTRAINT-style expressions** | The last group is not lavaan syntax, so the grammar becomes a **dialect**: `lavaanify()` cannot be the oracle for it, it needs its own tests, and the docs must label it as an extension. Bounds interact with the improper-solution policy (J6 spike: bounded fits changed Heywood answers). Constraints enlarge the parity gate (start-dependence seen with `a*b == 0`). |
| J16 | Multilevel | **Parse `level:` blocks now, with a `level` column in the table; fitting errors clearly; two-level estimation is a later stage after the OpenMx gate** | No rework of syntax or table later; the within/between likelihood (unbalanced clusters) is separate, large work. |
| J17 | Formulas | **Separate front ends:** formulas keep going to the glm/lmer engines; syntax goes to the SEM engines | No change for existing users; no formula-to-table bridge; two ways to state a simple mediation model. |

## Plan changes implied (not yet applied)

1. Add a **parser task** (own subset, oracle tests against `lavParseModelString()`) and a **converter task** (own table to ParTable and RAM, with round-trip tests) before N1/N2.
2. Add the `level` column and the `level:` refusal message to the table and parser tasks.
3. Add dialect tests for comma shorthand and CONSTRAINT-style expressions, and document them as extensions.
4. Add constrained cases and bounds cases to the v0 parity gate (OpenMx as oracle, J7), with the start-dependence caveat.

## Open questions

1. **Grammar spec:** who writes the frozen subset grammar, and where does it live (medfit docs, or a separate spec)?
2. **CONSTRAINT-style expressions:** arbitrary expressions need an expression evaluator and symbolic or numeric Jacobians. Which approach (symbolic differentiation, numeric Jacobian, or a restricted algebra)?
3. **Naming:** how is the dialect labeled to users so that "lavaan syntax" is not over-promised?
