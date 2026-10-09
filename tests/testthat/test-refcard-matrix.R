# The reference card (vignettes/articles/refcard.Rmd) is executed here: its
# engine x method x inference matrix is compared with what the code does, and
# every message in its error catalog is produced (or found in the source of the
# function that raises it). Skipped when the article is absent (it is
# .Rbuildignore'd, so R CMD check on the built package does not see it).

skip_if_not_installed("mice")
skip_if_not_installed("medfit")
card_path <- test_path("..", "..", "vignettes", "articles", "refcard.Rmd")
skip_if_not(file.exists(card_path), "refcard.Rmd is not part of the built package")
card <- readLines(card_path, encoding = "UTF-8")

# ---- parse the page ---------------------------------------------------------
cells <- function(line) trimws(strsplit(sub("^\\|", "", sub("\\|$", "", line)), "|", fixed = TRUE)[[1]])
section <- function(header) {
  i <- grep(paste0("^## ", header), card)
  rest <- card[(i + 1):length(card)]
  end <- grep("^## ", rest)
  rest <- if (length(end)) rest[seq_len(end[1] - 1)] else rest
  rest[grepl("^\\|", rest)][-(1:2)] # drop the header and the rule
}
matrix_rows <- section("What works where")
page_matrix <- do.call(rbind, lapply(matrix_rows, function(l) {
  x <- cells(l)
  data.frame(row = gsub("`", "", x[1]), t(ifelse(grepl("✔", x[-1]), "ok", "refused")))
}))
catalog <- do.call(rbind, lapply(section("Errors and warnings"), function(l) {
  x <- cells(l)
  data.frame(condition = x[1], msg = gsub("^`+ *| *`+$", "", x[2]), stringsAsFactors = FALSE)
}))

# ---- live behavior ----------------------------------------------------------
set.seed(1)
n <- 200
d <- data.frame(X = rbinom(n, 1, 0.5), C = rnorm(n))
d$M <- 0.5 * d$X + 0.3 * d$C + rnorm(n)
d$Y <- 0.3 * d$M + 0.2 * d$X + 0.3 * d$C + rnorm(n)
dm <- d
dm$M[sample(n, 30)] <- NA
imp <- suppressWarnings(mice::mice(dm, m = 3, method = "norm", printFlag = FALSE, seed = 1))
LMOD <- "M ~ X + C\nY ~ M + X + C"
md_of <- function(row) {
  switch(row,
    "glm, MI" = set_md_mediation(imp, Y ~ X + M + C, M ~ X + C, treatment = "X", mediator = "M"),
    "regmedint, MI" = set_md_mediation(imp, Y ~ X + M + C, M ~ X + C,
      treatment = "X", mediator = "M", engine = "regmedint"),
    "lavaan, MI" = set_md_mediation(imp, model = LMOD, treatment = "X", mediator = "M",
      outcome = "Y", engine = "lavaan"),
    "glm, IPW" = set_md_mediation(dm, Y ~ X + M + C, M ~ X + C, treatment = "X",
      mediator = "M", method = "ipw"),
    "lavaan, IPW" = set_md_mediation(dm, model = LMOD, treatment = "X", mediator = "M",
      outcome = "Y", engine = "lavaan", method = "ipw")
  )
}
works <- function(expr) {
  r <- tryCatch(suppressWarnings(expr), error = function(e) NULL)
  if (is.null(r)) "refused" else "ok"
}
live_row <- function(row) {
  md <- md_of(row)
  fit <- suppressWarnings(run(md))
  c(
    works(infer(pool(fit), type = "mc", n.mc = 1000)),
    works(infer(fit, type = "mbco")),
    works(sensitivity_mnar(md, delta = c(0, 0.5), n.mc = 500, seed = 1)),
    works(sensitivity_mnar(md, delta = c(0, 0.5), type = "mbco", seed = 1))
  )
}

test_that("the page has the five rows and the four columns it should", {
  expect_equal(nrow(page_matrix), 5L)
  expect_equal(ncol(page_matrix), 5L)
})

test_that("every cell of the matrix on the page equals what the code does", {
  for (i in seq_len(nrow(page_matrix))) {
    row <- page_matrix$row[i]
    if (row == "regmedint, MI") {
      skip_if_not_installed("regmedint")
      skip_if(utils::packageVersion("medfit") < "0.4.0", "regmedint needs medfit >= 0.4.0")
    }
    expect_equal(unname(unlist(page_matrix[i, -1])), live_row(row), info = row)
  }
})

# ---- the error and warning catalog ------------------------------------------
sep <- local({
  s <- list()
  for (k in 1:2) {
    set.seed(100 + k)
    X <- rnorm(100)
    M <- 0.5 * X + rnorm(100)
    s[[k]] <- data.frame(X = X, M = M, Y = if (k == 2) as.integer(M > 0) else rbinom(100, 1, plogis(0.8 * M)))
  }
  s
})
src <- function(f) gsub("\\\"", "\"", paste(deparse(f), collapse = "\n"), fixed = TRUE)
msg_of <- function(expr) tryCatch({ suppressWarnings(expr); "NO ERROR" }, error = function(e) conditionMessage(e))
lav_md <- function(fit_args = list()) {
  set_md_mediation(imp, model = LMOD, treatment = "X", mediator = "M", outcome = "Y",
    engine = "lavaan", fit_args = fit_args)
}
lat_md_of <- local({
  set.seed(51)
  n <- 150
  X <- rbinom(n, 1, 0.5)
  L <- 0.6 * X + rnorm(n)
  dl <- data.frame(X = X, m1 = L + rnorm(n, 0, 0.5), m2 = 0.8 * L + rnorm(n, 0, 0.5),
    m3 = 0.7 * L + rnorm(n, 0, 0.5))
  dl$Y <- 0.2 * X + 0.4 * L + rnorm(n)
  dl$m1[1:20] <- NA
  il <- suppressWarnings(mice::mice(dl, m = 2, maxit = 1, method = "norm", printFlag = FALSE, seed = 2))
  function(fit_args = list()) {
    set_md_mediation(il, model = "Ml =~ m1 + m2 + m3\nMl ~ X\nY ~ Ml + X", treatment = "X",
      mediator = "Ml", outcome = "Y", engine = "lavaan", fit_args = fit_args)
  }
})
triggers <- list(
  "is deprecated and will" = function() {
    w <- NULL
    try(withCallingHandlers(run(md_of("glm, MI"), m_star = 0), warning = function(x) {
      w <<- x
      invokeRestart("muffleWarning")
    }), silent = TRUE)
    expect_s3_class(w, "md_dots_deprecated")
    conditionMessage(w)
  },
  "did not converge on imputation" = function() {
    # An observed model can converge in one iteration; a latent one cannot.
    msg_of(run(lat_md_of(list(control = list(iter.max = 1)))))
  },
  "model did not converge" = function() {
    msg_of(mbco_d4(list(sep[[1]], sep[[2]], sep[[1]]), Y ~ M + X, M ~ X,
      family_y = stats::binomial(), treatment = "X", mediator = "M"))
  },
  "non-finite log-likelihood" = function() src(missingmed:::.mm_glm_ll),
  "lavaan model did not converge" = function() {
    msg_of(mbco_d4(mice::complete(imp, "all"), model = LMOD, treatment = "X", mediator = "M",
      outcome = "Y", fit_args = list(control = list(iter.max = 1))))
  },
  "improper solution" = function() src(missingmed:::.mm_warn_improper),
  "MBCO inference for IPW is not yet implemented" = function() {
    msg_of(infer(suppressWarnings(run(md_of("glm, IPW"))), type = "mbco"))
  },
  "supports estimator = \"ML\" only" = function() {
    msg_of(infer(suppressWarnings(run(lav_md(list(estimator = "MLR")))), type = "mbco"))
  },
  "at least 2 imputations" = function() {
    msg_of(mbco_d4(list(d), Y ~ M + X, M ~ X, treatment = "X", mediator = "M"))
  },
  "which the MBCO constraint drops" = function() {
    a <- b <- d
    a$X[3] <- NA
    msg_of(missingmed:::.mm_d4_mbco(list(a, b), Y ~ M + X, M ~ X, stats::gaussian(),
      stats::gaussian(), "X", "M"))
  },
  "Under ariv = \"fixed\"" = function() src(missingmed:::.mm_d4_pool),
  "not available for method = \"ipw\"" = function() {
    msg_of(sensitivity_mnar(md_of("glm, IPW"), delta = c(0, 0.5)))
  },
  "sensitivity rung" = function() src(sensitivity_mnar),
  "rung(s) failed" = function() src(sensitivity_mnar),
  "`target` is required" = function() {
    msg_of(sensitivity_mnar(lat_md_of(), delta = c(0, 0.5), n.mc = 500))
  }
)

test_that("every catalog row on the page has a trigger, and every trigger a row", {
  expect_setequal(catalog$msg, names(triggers))
})

test_that("every message in the catalog is what the code raises", {
  for (m in intersect(catalog$msg, names(triggers))) {
    got <- triggers[[m]]()
    expect_true(grepl(m, got, fixed = TRUE), info = m)
  }
})
