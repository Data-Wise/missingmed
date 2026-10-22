# T1 of SPEC-lavaan-mbco-on-mbco-sem-2026-10-16.md: label the a and b paths of a
# lavaan-syntax model so medfit's mbco_sem() can refit them. Built on
# lavaan::lavParseModelString(): a line-based regex breaks on `;`-separated
# statements and corrupts a formula continued on the next line (both are cases here).

lab <- function(model, ...) missingmed:::.mm_sem_label_model(model, "X", "M", "Y", ...)

# lavaan's own view of a model, minus the labels: the labeled text must describe
# the same model.
pt_key <- function(model) {
  pt <- lavaan::lavaanify(model, fixed.x = FALSE)
  pt[pt$op != ":=" & pt$op != "==", c("lhs", "op", "rhs", "free", "ustart", "exo")]
}
label_of <- function(model, lhs, rhs) {
  pt <- lavaan::lavParseModelString(model, as.data.frame. = TRUE, warn = FALSE)
  pt$label[pt$op == "~" & pt$lhs == lhs & pt$rhs == rhs]
}

test_that("an unlabeled model gets two distinct labels on exactly the a and b rows", {
  r <- lab("M ~ X\nY ~ M + X")
  expect_named(r, c("model", "a", "b"))
  expect_false(identical(r$a, r$b))
  expect_equal(label_of(r$model, "M", "X"), r$a)
  expect_equal(label_of(r$model, "Y", "M"), r$b)
  expect_equal(label_of(r$model, "Y", "X"), "")          # the direct path stays unlabeled
  expect_equal(pt_key(r$model), pt_key("M ~ X\nY ~ M + X"))
})

test_that("existing labels on the a and b paths are reused", {
  r <- lab("M ~ p*X\nY ~ q*M + X")
  expect_equal(c(r$a, r$b), c("p", "q"))
  expect_equal(pt_key(r$model), pt_key("M ~ p*X\nY ~ q*M + X"))
})

test_that("`;`-separated statements and a formula continued on the next line survive (regex breakers)", {
  r1 <- lab("M ~ X; Y ~ M + X")
  expect_equal(label_of(r1$model, "M", "X"), r1$a)
  expect_equal(label_of(r1$model, "Y", "M"), r1$b)
  expect_equal(pt_key(r1$model), pt_key("M ~ X\nY ~ M + X"))
  r2 <- lab("M ~ X\nY ~ M +\n  X # a comment")
  expect_equal(label_of(r2$model, "Y", "M"), r2$b)
  expect_equal(label_of(r2$model, "Y", "X"), "")
  expect_equal(pt_key(r2$model), pt_key("M ~ X\nY ~ M + X"))
})

test_that("`:=`, `==`, intercepts, `=~` and `~~` are carried through unchanged", {
  m <- paste("Ml =~ m1 + m2 + m3", "Ml ~ X", "Y ~ Ml + X", "m1 ~~ m2", "Y ~ 1",
    "ind := 0.5 * 2", "m3 ~~ v3*m3", "v3 == 0.5", sep = "\n")
  r <- missingmed:::.mm_sem_label_model(m, "X", "Ml", "Y")
  expect_equal(pt_key(r$model), pt_key(m))
  cons <- attr(lavaan::lavParseModelString(r$model, as.data.frame. = TRUE, warn = FALSE), "constraints")
  ops <- vapply(cons, function(z) z$op, "")
  expect_setequal(ops, c(":=", "=="))
})

test_that("the default label is never one the model already uses", {
  r <- lab("M ~ mm_a*X + mm_b*C\nY ~ M + X")
  expect_false(r$a %in% c("mm_b") && r$b == "mm_b")
  expect_equal(r$a, "mm_a")                                # reused, it is the a path's own label
  expect_false(identical(r$b, "mm_b"))                     # mm_b labels the C path: not reusable for b
  expect_equal(label_of(r$model, "M", "C"), "mm_b")
})

test_that("an absent path is refused, naming the count; a repeat collapses as in lavaan", {
  expect_error(lab("M ~ C\nY ~ M + X"), "exactly one `M ~ X`.*found 0")
  # lavaan collapses an identical repeat to one row (one parameter): not an error.
  expect_equal(lab("M ~ X\nM ~ X\nY ~ M")$a, lab("M ~ X\nY ~ M")$a)
  # A repeat with another label collapses to one row, last label wins: what lavaan::sem() fits.
  expect_equal(lab("M ~ p*X\nM ~ q*X\nY ~ M")$a, "q")
  expect_error(lab("M ~ X\nY ~ X"), "exactly one `Y ~ M`.*found 0")
})

test_that("a path fixed in the syntax is refused: there is no parameter to test", {
  expect_error(lab("M ~ 0.5*X\nY ~ M + X"), "fixed")
  expect_error(lab("M ~ X\nY ~ 0*M + X"), "fixed")
})

test_that("a tested path with a second modifier is refused, naming it (medfit allows one per term)", {
  expect_error(lab("M ~ start(0.3)*X\nY ~ M + X"), "start")
  expect_error(lab("M ~ X\nY ~ q*M + lower(0)*X + start(0.1)*M"), "found 2|start")
})

test_that("a free-loading `NA*` modifier is refused, naming it", {
  expect_error(missingmed:::.mm_sem_label_model(
    "Ml =~ NA*m1 + m2\nMl ~ X\nY ~ Ml + X", "X", "Ml", "Y"), "NA\\*")
})

test_that("a multi-group label on a tested path is refused", {
  expect_error(lab("M ~ c(a1, a2)*X\nY ~ M + X"), "multi-group")
})

test_that("both tested paths sharing one label is refused (they would be one parameter)", {
  expect_error(lab("M ~ p*X\nY ~ p*M + X"), "same label")
})

test_that("unsupported untested modifiers are refused without malformed rewriting", {
  expect_error(lab("M ~ X; Y ~ M + c(1,2)*X"), "multi-group c")
  expect_error(lab('M ~ X; Y ~ M; M ~~ equal("Y~~Y")*M'), "equal")
})

test_that("generated labels avoid defined and constraint names", {
  r <- lab("M ~ X; Y ~ M; mm_a := 1*2; mm_b := 3")
  expect_equal(c(r$a, r$b), c("mm_a_", "mm_b_"))
  expect_silent(lavaan::lavaanify(r$model))
})

test_that("tested labels shared with variances refuse singular zero nulls", {
  expect_error(lab("M ~ p*X; X ~~ p*X; Y ~ q*M + X"), "p.*variance.*singular")
  expect_error(lab("M ~ p*X; Y ~ q*M + X; Y ~~ q*Y"), "q.*variance.*singular")
  expect_equal(lab("M ~ p*X; Y ~ q*M + p*X")$a, "p")
})
