#' Run a random forest based summary fo the MOEDA methos
#'
#' @param df A data.framish object which is the object of MOEDA analysis
#' @param target_var_name A character scalar representing the name of the target
#' variable in the analysis
#'
#' @return A list with a tibble regarding permutation variable importance
#' metrics and information whether the model run in a clessification or
#' regression setting.
#'
run_rf_summary <- function(df, target_var_name) {

  set.seed(1)
  usable_cores <- (parallel::detectCores() - 1) %>% {ifelse(. < 1, 1, .)}
  model_mode <-
    if(is.numeric(df[[target_var_name]])) "regression" else "classification"
  cv_split <- rsample::initial_split(
    df %>%
      mutate(
        across(where(~ is.character(.x) | is.logical(.x)), as.factor),
        across(where(~ any(is.na(.x))))
      ),
    prop = 0.8
  )

  message("Fitting a simple random forest model, this might take some time...")
  rf_model <-
    parsnip::rand_forest(mode = model_mode) %>%
    parsnip::set_engine(
      "ranger", importance = "permutation", num.threads = usable_cores
    ) %>%
    parsnip::fit(
      stats::as.formula(glue("{target_var_name}~.")),
      data = rsample::training(cv_split)
    )

  var_importance <- rf_model$fit$variable.importance %>%
    {dplyr::tibble(variable_name = names(.), permutation_importance = .)} %>%
    dplyr::arrange(dplyr::desc(permutation_importance)) %>%
    mutate(
      perc_share = permutation_importance / sum(permutation_importance),
      cum_perc = cumsum(perc_share),
      perc_diff =
        permutation_importance %>% {(. - dplyr::lag(.)) / .} %>% round(2)
    )

  print(var_importance, n = Inf)

  # unfortunately missing num values are not handled in prediction of ranger
  # TODO check if Random Forest is free of this issue
  initial_test_n <- nrow(rsample::testing(cv_split))
  test_df <- rsample::testing(cv_split) %>% stats::na.omit()

  if (initial_test_n > nrow(test_df)) message(glue(
    "Test performance will be calculated on {nrow(test_df)} out of initially ",
    "picked {initial_test_n} samples due to NA values."
  ))

  model_performance <-
    dplyr::tibble(
      truth = test_df[[target_var_name]],
      predicted = parsnip::predict.model_fit(rf_model, new_data = test_df)[[1]]
    ) %>%
    yardstick::metrics(truth, predicted)
  print(model_performance)

  list(var_importance = var_importance, model_mode = model_mode)
}


