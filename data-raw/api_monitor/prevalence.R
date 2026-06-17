suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
})

prev_paths <- function(state_dir) {
  list(
    fields = file.path(state_dir, "prevalence.tsv"),
    periods = file.path(state_dir, "periods.tsv")
  )
}

read_prev_state <- function(state_dir = "data-raw/api_monitor/state") {
  p <- prev_paths(state_dir)
  fields <- if (file.exists(p$fields)) {
    readr::read_tsv(p$fields, col_types = "cccdic")
  } else {
    tibble::tibble(endpoint = character(), path = character(), type = character(),
                   k_cum = numeric(), periods_seen = integer(), last_period = character())
  }
  periods <- if (file.exists(p$periods)) {
    readr::read_tsv(p$periods, col_types = "ccdc")
  } else {
    tibble::tibble(period = character(), endpoint = character(), n = numeric(), date = character())
  }
  list(fields = fields, periods = periods)
}

write_prev_state <- function(state_dir, fields, periods) {
  dir.create(state_dir, showWarnings = FALSE, recursive = TRUE)
  p <- prev_paths(state_dir)
  readr::write_tsv(dplyr::arrange(fields, endpoint, path), p$fields)
  readr::write_tsv(dplyr::arrange(periods, date, endpoint), p$periods)
}

eb_beta <- function(prevalence, n_total) {
  prevalence <- prevalence[is.finite(prevalence)]
  if (length(prevalence) < 3) return(c(alpha = 0.5, beta = 0.5))
  m <- mean(prevalence)
  v <- stats::var(prevalence)
  if (v <= 0 || m <= 0 || m >= 1 || v >= m * (1 - m)) return(c(alpha = 0.5, beta = 0.5))
  k <- m * (1 - m) / v - 1
  c(alpha = max(m * k, 1e-3), beta = max((1 - m) * k, 1e-3))
}

encounter_prob <- function(alpha, beta, m) 1 - exp(lbeta(alpha, beta + m) - lbeta(alpha, beta))

prob_miss <- function(alpha, beta, n) exp(lbeta(alpha, beta + n) - lbeta(alpha, beta))

sample_for_coverage <- function(alpha, beta, target) {
  m <- 1
  while (encounter_prob(alpha, beta, m) < target && m < 1e7) m <- m * 2L
  m
}

build_prev_report <- function(coverage, new_fields, suspected_removed, model, period_id, target_m) {
  fmt <- function(x) formatC(x, format = "f", digits = 3)
  lines <- c(paste0("# Bayesian schema-prevalence report (", period_id, ")"), "")
  for (ep in coverage$endpoint) {
    c1 <- dplyr::filter(coverage, endpoint == ep)
    lines <- c(lines,
      paste0("## ", ep),
      paste0("- learned prior Beta(", fmt(c1$prior_alpha), ", ", fmt(c1$prior_beta),
             "); N=", c1$N, " entities over ", c1$n_periods, " period(s)"),
      paste0("- observed ", c1$observed, " fields; Chao1 richness ", round(c1$chao1, 1),
             " (~", round(c1$est_unseen, 1), " unseen); coverage ", fmt(c1$coverage)),
      paste0("- P(next entity reveals an unseen field) = ", fmt(c1$p_next_new)),
      "")
  }
  if (nrow(new_fields)) {
    lines <- c(lines, "## New fields this period",
      paste0("- `", new_fields$endpoint, ".", new_fields$path, "` (posterior prevalence ",
             fmt(new_fields$prevalence), ")"), "")
  }
  lines <- c(lines, "## Suspected removed (high prevalence, absent this period)",
    if (nrow(suspected_removed)) {
      paste0("- `", suspected_removed$endpoint, ".", suspected_removed$path,
             "` prevalence ", fmt(suspected_removed$prevalence),
             ", P(miss|posterior)=", fmt(suspected_removed$p_miss_period),
             " over ", suspected_removed$absent_periods, " absent period(s)")
    } else "- none", "")
  rare <- dplyr::arrange(model, p_encounter_m) |> head(8)
  lines <- c(lines, paste0("## Rarest known fields (P(encounter) in an ", target_m, "-entity sample)"),
    paste0("- `", rare$endpoint, ".", rare$path, "` prevalence ", fmt(rare$prevalence),
           ", P(encounter)=", fmt(rare$p_encounter_m)))
  paste(lines, collapse = "\n")
}

bayes_period <- function(counts_path, state_dir = "data-raw/api_monitor/state",
                         target_m = 5000, remove_thresh = 0.02, remove_prev = 0.2,
                         update_baseline = FALSE) {
  cur <- readr::read_tsv(counts_path, show_col_types = FALSE)
  st <- read_prev_state(state_dir)
  period_id <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  n_period <- cur |> dplyr::distinct(endpoint, n) |> dplyr::rename(n_period = n)

  prior_last <- st$fields |> dplyr::select(endpoint, path, prev_last = last_period)
  fields <- dplyr::full_join(
    st$fields |> dplyr::select(endpoint, path, type, k_cum, periods_seen, last_period),
    cur |> dplyr::transmute(endpoint, path, type_new = type, k_new = k),
    by = c("endpoint", "path")
  ) |>
    dplyr::mutate(
      type = dplyr::coalesce(type_new, type),
      seen_now = !is.na(k_new) & k_new > 0,
      is_new = (is.na(k_cum) | k_cum == 0) & seen_now,
      prev_last_period = last_period,
      k_cum = dplyr::coalesce(k_cum, 0) + dplyr::coalesce(k_new, 0),
      periods_seen = dplyr::coalesce(periods_seen, 0L) + as.integer(seen_now),
      last_period = ifelse(seen_now, period_id, last_period)
    )

  periods_new <- n_period |> dplyr::transmute(period = period_id, endpoint, n = n_period, date = period_id)
  periods_all <- dplyr::bind_rows(st$periods, periods_new)
  Ntab <- periods_all |> dplyr::group_by(endpoint) |>
    dplyr::summarise(N = sum(n), n_periods = dplyr::n(), .groups = "drop")

  model <- fields |>
    dplyr::left_join(Ntab, by = "endpoint") |>
    dplyr::left_join(n_period, by = "endpoint") |>
    dplyr::group_by(endpoint) |>
    dplyr::group_modify(function(df, key) {
      pr <- eb_beta(df$k_cum / df$N, df$N)
      df |>
        dplyr::mutate(
          prior_alpha = unname(pr["alpha"]), prior_beta = unname(pr["beta"]),
          a_post = pr["alpha"] + k_cum,
          b_post = pr["beta"] + N - k_cum,
          prevalence = a_post / (a_post + b_post),
          lo = stats::qbeta(0.025, a_post, b_post),
          hi = stats::qbeta(0.975, a_post, b_post),
          p_encounter_m = encounter_prob(a_post, b_post, target_m),
          p_miss_period = prob_miss(a_post, b_post, n_period)
        )
    }) |>
    dplyr::ungroup()

  suspected_removed <- model |>
    dplyr::filter(!seen_now, prevalence >= remove_prev, p_miss_period < remove_thresh) |>
    dplyr::mutate(absent_periods = n_periods - periods_seen) |>
    dplyr::arrange(p_miss_period)

  new_fields <- dplyr::filter(model, is_new)

  coverage <- model |>
    dplyr::group_by(endpoint) |>
    dplyr::summarise(
      observed = dplyr::n(),
      f1 = sum(k_cum == 1), f2 = sum(k_cum == 2),
      N = dplyr::first(N), n_periods = dplyr::first(n_periods),
      prior_alpha = dplyr::first(prior_alpha), prior_beta = dplyr::first(prior_beta),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      chao1 = observed + ifelse(f2 > 0, f1^2 / (2 * f2), f1 * (f1 - 1) / 2),
      est_unseen = pmax(chao1 - observed, 0),
      p_next_new = f1 / N,
      coverage = observed / chao1
    )

  report <- build_prev_report(coverage, new_fields, suspected_removed, model, period_id, target_m)
  out_fields <- model |> dplyr::select(endpoint, path, type, k_cum, periods_seen, last_period)
  if (update_baseline || nrow(st$fields) == 0) write_prev_state(state_dir, out_fields, periods_all)

  list(report = report, model = model, coverage = coverage,
       new_fields = new_fields, suspected_removed = suspected_removed,
       fields = out_fields, periods = periods_all,
       drift = nrow(new_fields) > 0 || nrow(suspected_removed) > 0)
}
