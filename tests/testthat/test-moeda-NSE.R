test_that("MOEDA accepts unquoted, quoted and variable inputs to target_var", {

  moeda_basic <- moeda(mtcars, mpg)
  expect_equal(moeda_basic, moeda(mtcars, "mpg"))

  string_var_name <- "mpg"
  expect_equal(moeda_basic, moeda(mtcars, string_var_name))

})
