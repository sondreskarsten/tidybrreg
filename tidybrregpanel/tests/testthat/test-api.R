# Live API tests for tidybrregpanel (skip_if_offline() in helper-api.R)

test_that("brreg_board_summary computes correctly", {
  skip_if_offline()
  roles <- safely(brreg_roles("923609016"))
  bs <- brreg_board_summary(roles)
  expect_equal(nrow(bs), 1)
  expect_gt(bs$board_size, 0)
  expect_true(is.logical(bs$has_ceo))
  expect_true(is.logical(bs$has_auditor))
})
