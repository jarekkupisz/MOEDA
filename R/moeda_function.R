#' Run a MOEDA Analysis
#'
#' The main function of the package that runs Modeling-Oriented Exploratory
#' Data Analysis on your data.
#'
#'Currently, this function performs the following actions:
#' \enumerate{
#'   \item A random forest is run on the training set with 80 percent of
#'   observations
#'   \item Permutation variable importance is exported from the model and
#'   reported to the console together with some additional information
#'   \item Model's performance is assessed on the test set of the remaining
#'   20 percent of observations and reported to the console
#'   \item Top variables (their number can be specified with `n_top_vars`
#'   argument) are discretized using equal widths discretization via
#'   `base::cut()`. You can select the number of cuts with the `cuts` argument.
#'   \item An upset plot of the intersections from 4. together with target
#'   variables is printed.
#'   \item A `GGally::ggpairs()` plot of top variables is printed.
#'   \item The function returns the original `df` and joins top features
#'   columns that were cut together with resulting intersections.
#'   These additional columns have `moedized` in their name.
#' }
#'
#' @param df A dataset you wish to analyze, typically a data.frame or a tibble
#' @param target_var Unquoted expression or a scalar character representing the
#' column in the `df` that is your target (aka dependent) variable for analysis
#' @param n_top_vars An integer scalar specifying up to how many top variables
#' you wish to consider for your analysis. By default 4
#' @param cuts An integer scalar telling `base::cut()` how many equal width
#' buckets to create in the top_vars. By default 4
#' @param ... Arguments passed to `base::cut()`
#'
#' @return The original df as a tibble with joined top features columns that
#' were cut together with resulting intersections. These additional columns
#' have `moedized` in their name.
#'
#' @export
moeda <- function(df, target_var, n_top_vars = 4, cuts = 4, ...) {

  #..................Target Variable Determination and basic assertions.........
  target_var_name <- select(df, {{target_var}}) %>% colnames()

  assert_that(
    assertthat::is.string(target_var_name),
    msg = "target_var does not represent a single column in the df"
  )
  assert_that(
    is.atomic(df[[target_var_name]]),
    msg = glue("target_var ({target_var_name}) is not an atomic vector")
  )

  non_atomic_cols <-
    sapply(df, function(x) !is.atomic(x)) %>%
    .[. %in% TRUE] %>%
    names()

  if (length(non_atomic_cols) > 0) {
    message(glue(
      "The following non-atomic columns will be dropped: ",
      paste0(non_atomic_cols, collapse = ", "), "."
    ))

    df <- df %>% select(-all_of(non_atomic_cols))
  }

  #................Printing RF Summary.............................
  rf_summary <- run_rf_summary(df, target_var_name)
  top_vars <-
    rf_summary$var_importance %>%
    dplyr::slice(1:n_top_vars) %>%
    dplyr::pull(variable_name)
  classification_context <- rf_summary$model_mode %in% "classification"

  #................Constructing upset and final intersections................
  cut_top_vars_df <-
    df %>%
    select(all_of(top_vars)) %>%
    mutate(across(
      where(~ is_cuttable(.x, cuts)),
      base::cut,
      cuts, include.lowest = TRUE, ...,
    )) %>%
    dplyr::rowwise() %>% #TODO performance issues
    mutate(
      moeda_intersections = dplyr::cur_data() %>%
        as.list() %>%
        sapply(as.character) %>%
        {paste0(names(.), ": ", ., collapse = " ~ ")}
    ) %>%
    dplyr::ungroup() %>%
    dplyr::rename_with(paste0, .cols = -moeda_intersections, "_moedized")

  upset_cut_df <- cut_top_vars_df %>%
    select(-moeda_intersections) %>%
    dplyr::rename_with(~ gsub("_moedized", "", .x)) %>%
    {recipes::recipe(~ ., data = .)} %>%
    recipes::step_dummy(recipes::all_predictors(), one_hot = TRUE) %>%
    recipes::prep() %>%
    recipes::bake(new_data = NULL)

  message(glue(
    "Printing an upset plot with MOEDA intersections of top vars. ",
    "Please browse back in the plots output pane if you wish to see it."
  ))
  suppressMessages(print(
    upset_cut_df %>%
      mutate(target_var_plot = df[[target_var_name]]) %>%
      ComplexUpset::upset(
        colnames(.) %>% .[!. %in% "target_var_plot"],
        n_intersections = 10,
        annotations = list(
          target_var_upset_annot = if (classification_context) {
            ggplot2::ggplot() +
              ggplot2::aes(fill = target_var_plot) +
              ggplot2::geom_bar(stat = 'count', position = 'fill') +
              ggplot2::ylab(target_var_name)
          } else {
            ggplot2::ggplot() +
              ggplot2::aes(y = target_var_plot) +
              ggplot2::geom_boxplot() +
              ggplot2::ylab(target_var_name)
          }
        )
      )
  ))

  message("Printing a GGally::ggpairs of target variable and top features.")
  suppressMessages(print(GGally::ggpairs(
    df,
    c(target_var_name, top_vars),
    mapping = if (classification_context)
      ggplot2::aes(color = !!ggplot2::sym(target_var_name)) else NULL,
    switch = "y",
    cardinality_threshold = NULL,
    progress = FALSE
  )))

  message("Returning moedized data across n_top_vars")
  # TODO do a moeda object wich contain data and charts
  dplyr::bind_cols(df, cut_top_vars_df) %>% dplyr::as_tibble()
}



