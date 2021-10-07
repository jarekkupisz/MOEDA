test_that("MOEDA runs for each type of classification", {

  expect_visible(moeda(mtcars, mpg))
  expect_visible(moeda(mtcars %>% dplyr::mutate(mpg = mpg >= mean(mpg)), mpg))
  expect_visible(moeda(iris, Species))

})
