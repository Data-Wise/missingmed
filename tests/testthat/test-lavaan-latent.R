# Latent mediator and MNAR sensitivity with engine = "lavaan" (PLAN T5, T7; G4).

skip_if_not_installed("mice")
skip_if_not_installed("lavaan")

gen_lat <- function(n = 300, seed = 51) {
  set.seed(seed)
  C <- rnorm(n)
  X <- rbinom(n, 1, .5)
  L <- .6 * X + .3 * C + rnorm(n)
  d <- data.frame(
    X, C,
    m1 = L + rnorm(n, 0, .5), m2 = .8 * L + rnorm(n, 0, .5),
    m3 = .7 * L + rnorm(n, 0, .5)
  )
  d$Y <- .2 * X + .5 * L + .3 * C + rnorm(n)
  d$m1[1:40] <- NA
  d$m2[41:70] <- NA
  d
}
imp_lat <- suppressWarnings(
  mice::mice(gen_lat(), m = 3, maxit = 2, method = "norm", printFlag = FALSE, seed = 2)
)
mod_lat <- "Mlat =~ m1 + m2 + m3\nMlat ~ a*X + C\nY ~ b*Mlat + cp*X + C"
md_lat <- set_md_mediation(imp_lat,
  model = mod_lat, treatment = "X", mediator = "Mlat",
  outcome = "Y", engine = "lavaan"
)

test_that("a latent-mediator model runs through run -> pool -> infer('mc')", {
  fit <- run(md_lat)
  res <- pool(fit)
  tab <- res@tidy_table
  expect_true(all(c("a", "b", "c_prime", "Mlat=~m2") %in% tab$term))
  expect_true(all(is.finite(tab$estimate)))
  set.seed(1)
  r <- infer(fit, type = "mc", n.mc = 5000)
  expect_true(all(is.finite(r$CI)))
  expect_equal(r$Estimate, tab$estimate[tab$term == "a"] * tab$estimate[tab$term == "b"],
    tolerance = 0.02
  )
})

test_that("an observed-mediator lavaan fit is unaffected by the latent handling", {
  d <- gen_lat()
  d$Mo <- (d$m1 + d$m2 + d$m3) / 3
  imp <- suppressWarnings(
    mice::mice(d, m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 1)
  )
  md <- set_md_mediation(imp,
    model = "Mo ~ a*X + C\nY ~ b*Mo + cp*X + C", treatment = "X",
    mediator = "Mo", outcome = "Y", engine = "lavaan"
  )
  expect_s3_class(pool(run(md)), "missingmed::MDMediationResult")
})

# -- sensitivity_mnar() ------------------------------------------------------

test_that("sensitivity_mnar(type = 'mc') runs on a lavaan fit with an observed target", {
  s <- sensitivity_mnar(md_lat, delta = c(0, 0.5), target = "m1", n.mc = 2000, seed = 1)
  expect_s3_class(s, "missingmed::MDSensitivityResult")
  expect_equal(nrow(tidy(s)), 2L)
})

test_that("a latent mediator with target = NULL errors before re-imputing, listing indicators", {
  expect_error(
    sensitivity_mnar(md_lat, delta = c(0, 0.5), n.mc = 2000),
    "latent.*`target` is required.*m1, m2, m3"
  )
  expect_error(
    sensitivity_mnar(md_lat, ums = c(0, 0.5), n.mc = 2000),
    "`target` is required"
  )
})

test_that("type = 'mbco' is refused for lavaan before re-imputing", {
  expect_error(
    sensitivity_mnar(md_lat, delta = c(0, 0.5), target = "m1", type = "mbco"),
    "not available for engine"
  )
})
