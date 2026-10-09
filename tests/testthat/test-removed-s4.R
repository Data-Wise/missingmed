# The S4 stubs were deleted in 0.7.0; their names must not come back by accident.

test_that("the removed S4 functions are no longer exported", {
  removed <- c("set_sem", "run_sem", "pool_sem", "fit_model", "lav_mice", "mx_mice")
  expect_false(any(removed %in% getNamespaceExports("missingmed")))
})

test_that("the S7 replacements named in the migration guide are exported", {
  expect_true(all(c("set_md_mediation", "run", "pool", "infer") %in%
    getNamespaceExports("missingmed")))
})
