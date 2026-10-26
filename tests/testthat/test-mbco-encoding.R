# Item 10: injected summaries only; no medfit-specific skip or fitting.
test_that("encoding, own/fixed selection, ties and labeled diagnostics are independent", {
  imps <- list(data.frame(id = 1), data.frame(id = 2))
  # Raw branch LRs: (1,9), (9,3), stack (8,12). Own mean=2; fixed mean=5.
  rows <- rbind(c(1, 9), c(9, 3), c(8, 12))
  provider <- function(d) {
    i <- if (nrow(d) == 2L) 3L else d$id
    c(full = 0, a = -rows[i, 1] / 2, b = -rows[i, 2] / 2, k_a = 1, k_b = 1)
  }
  for (mode in c("own", "fixed")) {
    r <- missingmed:::.mm_d4_pool(imps, provider, mode)
    riv <- if (mode == "own") 0 else 3
    expect_equal(r[["d_S"]], 4)
    expect_equal(r[["r4"]], riv)
    expect_equal(r[["D4"]], 4 / (1 + riv))
    expect_identical(r@stacked_branch, "a")
    expect_true(r@branch_mix)
    expect_equal(r@p_branch_a, 0.5)
    expect_equal(r["p"], c(p = r[["p"]]))
    expect_error(r$p)
    swapped <- function(d) { z <- provider(d); z[c("a", "b")] <- z[c("b", "a")]; z }
    s <- missingmed:::.mm_d4_pool(imps, swapped, mode)
    expect_equal(as.vector(r), as.vector(s))
    expect_identical(s@stacked_branch, "b")
  }
})

test_that("ties select a without shared provider state", {
  provider <- function(d) c(full = 0, a = -2, b = -2, k_a = 1, k_b = 1)
  tie <- missingmed:::.mm_d4_pool(list(data.frame(id = 1), data.frame(id = 2)), provider)
  expect_identical(tie@stacked_branch, "a")
  expect_false(tie@branch_mix)
  expect_equal(tie@p_branch_a, 1)
})

test_that("imputation-only k mismatch is independent of tie setup", {
  imps <- list(data.frame(id = 1), data.frame(id = 2))
  bad <- function(d) {
    k_a <- if (nrow(d) == 1L && d$id == 2) 2 else 1
    c(full = 0, a = -1, b = -3, k_a = k_a, k_b = 1)
  }
  for (mode in c("fixed", "own")) {
    expect_error(missingmed:::.mm_d4_pool(imps, bad, mode), "(single k|different number)")
  }
})

item10_imps <- function() lapply(1:3, function(i) data.frame(id = i))
item10_provider <- function(d) {
  lr <- if (nrow(d) == 3L) c(9, 18) else c(4 + 2 * d$id, 10 + 2 * d$id)
  c(full = 0, a = -lr[1] / 2, b = -lr[2] / 2, k_a = 1, k_b = 2)
}

item10_provider_k2 <- function(d) {
  z <- item10_provider(d)
  z[c("k_a", "k_b")] <- c(2, 3)
  z
}

test_that("winning k two pins every dimension-dependent statistic and paired swap", {
  # Same mean LR=8 and d_S=3, but r4=(4/4)*5=5.
  # D4=3/(2*6)=1/4; nu=2*2*(6/5)^2=144/25.
  expected <- c(D4 = 1 / 4, r4 = 5, nu = 144 / 25, d_S = 3,
    p = stats::pf(1 / 4, 2, 144 / 25, lower.tail = FALSE))
  swapped <- function(d) {
    z <- item10_provider_k2(d)
    z[c("a", "b", "k_a", "k_b")] <- z[c("b", "a", "k_b", "k_a")]
    z
  }
  for (mode in c("own", "fixed")) {
    r <- missingmed:::.mm_d4_pool(item10_imps(), item10_provider_k2, mode)
    for (nm in names(expected)) expect_equal(r[[nm]], expected[[nm]], tolerance = 1e-12)
    expect_equal(r@k, 2)
    expect_identical(r@stacked_branch, "a")
    s <- missingmed:::.mm_d4_pool(item10_imps(), swapped, mode)
    expect_equal(as.vector(s), as.vector(r))
    expect_equal(s@k, 2)
    expect_identical(s@stacked_branch, "b")
  }
})

test_that("three imputations pin positive own ARIV and nonbinary stack scaling", {
  # Per-imputation LR mean=8; stacked LR/K=9/3=3.
  # r4=(4/2)*(8-3)=10; D4=3/11; nu=2*(11/10)^2=121/50.
  for (mode in c("own", "fixed")) {
    r <- missingmed:::.mm_d4_pool(item10_imps(), item10_provider, mode)
    expected <- c(D4 = 3 / 11, r4 = 10, nu = 121 / 50, d_S = 3,
      p = stats::pf(3 / 11, 1, 121 / 50, lower.tail = FALSE))
    for (nm in names(expected)) expect_equal(r[[nm]], expected[[nm]], tolerance = 1e-12)
    expect_equal(r@k, 1)
    expect_false(r@branch_mix)
    expect_equal(r@p_branch_a, 1)
  }
})

test_that("stack-only k mismatch refuses while losing k and paired swaps remain valid", {
  for (mode in c("own", "fixed")) {
    bad <- function(d) {
      z <- item10_provider(d)
      if (nrow(d) == 3L) z["k_a"] <- 3
      z
    }
    expect_error(missingmed:::.mm_d4_pool(item10_imps(), bad, mode),
      if (mode == "own") "different number" else "stacked data.*single k")
    losing <- function(d) {
      z <- item10_provider(d)
      z["k_b"] <- if (nrow(d) == 3L) 9 else d$id + 2
      z
    }
    r <- missingmed:::.mm_d4_pool(item10_imps(), losing, mode)
    expect_equal(r[["D4"]], 3 / 11)
    swapped <- function(d) {
      z <- item10_provider(d)
      z[c("a", "b", "k_a", "k_b")] <- z[c("b", "a", "k_b", "k_a")]
      z
    }
    s <- missingmed:::.mm_d4_pool(item10_imps(), swapped, mode)
    expect_equal(as.vector(s), as.vector(r))
    expect_identical(s@stacked_branch, "b")
    expect_equal(s@k, 1)
  }
})

item10_replace <- function(fun, old, new) {
  count <- 0L
  walk <- function(x) {
    if (identical(x, old)) { count <<- count + 1L; return(new) }
    if (is.call(x)) for (i in seq_along(x)) x[[i]] <- walk(x[[i]])
    x
  }
  body(fun) <- walk(body(fun))
  stopifnot(count == 1L)
  fun
}

test_that("stack scaling and stack-k mutants reach and fail intended assertions", {
  pool <- missingmed:::.mm_d4_pool
  wrong_scale <- item10_replace(pool, quote(unname(st[["T"]]) / K),
    quote(unname(st[["T"]]) / 2))
  r <- wrong_scale(item10_imps(), item10_provider, "own")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_failure(expect_equal(r[["d_S"]], 3))
  wrong_k <- item10_replace(pool, quote(unique(c(per[2L, ], st[["k"]]))),
    quote(unique(per[2L, ])))
  bad <- function(d) {
    z <- item10_provider(d)
    if (nrow(d) == 3L) z["k_a"] <- 3
    z
  }
  r <- wrong_k(item10_imps(), bad, "own")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_failure(expect_error(wrong_k(item10_imps(), bad, "own"), "different number"))
})

test_that("fixed-mode scaling and stack comparison mutants fail intended assertions", {
  pool <- missingmed:::.mm_d4_pool
  wrong_scale <- item10_replace(pool, quote(unname(.mm_mbco_T_from_lls(lls_S)) / K),
    quote(unname(.mm_mbco_T_from_lls(lls_S)) / 2))
  r <- wrong_scale(item10_imps(), item10_provider, "fixed")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_failure(expect_equal(r[["d_S"]], 3))
  wrong_k <- item10_replace(pool, quote(k_i != k_S), quote(FALSE))
  bad <- function(d) {
    z <- item10_provider(d)
    if (nrow(d) == 3L) z["k_a"] <- 3
    z
  }
  r <- wrong_k(item10_imps(), bad, "fixed")
  expect_true(S7::S7_inherits(r, MbcoMIResult))
  expect_failure(expect_error(wrong_k(item10_imps(), bad, "fixed"), "stacked data.*single k"))
})

test_that("k two rejects omitted dimension factors in ARIV, D4, df and F tail", {
  originals <- list(quote(max(0, (K + 1) / (k * (K - 1)) * gap)), quote(k * (1 + r4)),
    quote(k * (K - 1) * (1 + 1 / r4)^2), quote(stats::pf(D4, k, nu, lower.tail = FALSE)))
  replacements <- list(quote(max(0, (K + 1) / (K - 1) * gap)), quote(1 + r4),
    quote((K - 1) * (1 + 1 / r4)^2), quote(stats::pf(D4, 1, nu, lower.tail = FALSE)))
  fields <- c("r4", "D4", "nu", "p")
  expected <- c(5, 1 / 4, 144 / 25, stats::pf(1 / 4, 2, 144 / 25, lower.tail = FALSE))
  for (i in seq_along(fields)) {
    # A private lexical binding changes only this cloned pool's helper.
    pool <- missingmed:::.mm_d4_pool
    private <- new.env(parent = environment(pool))
    private$.mm_d4_from_stats <- item10_replace(missingmed:::.mm_d4_from_stats,
      originals[[i]], replacements[[i]])
    environment(pool) <- private
    for (mode in c("own", "fixed")) {
      r <- pool(item10_imps(), item10_provider_k2, mode)
      expect_true(S7::S7_inherits(r, MbcoMIResult))
      expect_failure(expect_equal(r[[fields[i]]], expected[i], tolerance = 1e-12))
    }
  }
})
