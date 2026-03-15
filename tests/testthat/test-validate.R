test_that("brreg_validate accepts valid org numbers", {
  expect_true(brreg_validate("923609016"))
  expect_true(brreg_validate("984851006"))
  expect_true(brreg_validate("974760673"))
})

test_that("brreg_validate rejects invalid org numbers", {
  expect_false(brreg_validate("123456789"))
  expect_false(brreg_validate("984851007"))
  expect_false(brreg_validate("12345"))
  expect_false(brreg_validate(""))
  expect_false(brreg_validate("abcdefghi"))
})

test_that("brreg_validate is vectorized", {
  result <- brreg_validate(c("923609016", "123456789", "984851006"))
  expect_equal(result, c(TRUE, FALSE, TRUE))
})

test_that("brreg_validate handles edge cases", {
  expect_false(brreg_validate("000000000"))
  expect_false(brreg_validate("100000000"))
  expect_length(brreg_validate(character(0)), 0)
})
