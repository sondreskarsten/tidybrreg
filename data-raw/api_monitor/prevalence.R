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
    readr::read_tsv(p$fields, col_types = "ccccdic")
  } else {
    tibble::tibble(endpoint = character(), segment = character(), path = character(),
                   type = character(), k_cum = numeric(), periods_seen = integer(),
                   last_period = character())
  }
  periods <- if (file.exists(p$periods)) {
    readr::read_tsv(p$periods, col_types = "cccdc")
  } else {
    tibble::tibble(period = character(), endpoint = character(), segment = character(),
                   n = numeric(), date = character())
  }
  list(fields = fields, periods = periods)
}

read_pops <- function(counts_path) {
  pp <- paste0(counts_path, ".pop")
  if (!file.exists(pp)) return(tibble::tibble(state = character(), population = numeric()))
  readr::read_tsv(pp, col_types = "cd")
}

write_prev_state <- function(state_dir, fields, periods) {
  dir.create(state_dir, showWarnings = FALSE, recursive = TRUE)
  p <- prev_paths(state_dir)
  readr::write_tsv(dplyr::arrange(fields, endpoint, segment, path), p$fields)
  readr::write_tsv(dplyr::arrange(periods, date, endpoint, segment), p$periods)
}

cond_prevalence <- function(k, n) (k + 0.5) / (n + 1)

seg_form <- function(segment) sub("\\|.*", "", segment)
seg_state <- function(segment) sub(".*\\|", "", segment)

build_cond_report <- function(seg_cov, slices, drivers, new_fields, removed, period_id) {
  fmt <- function(x) formatC(x, format = "f", digits = 3)
  pint <- function(x) ifelse(is.na(x), "?", formatC(x, format = "d", big.mark = ""))
  lines <- c(paste0("# Conditional schema-presence report (", period_id, ")"), "")
  for (ep in unique(seg_cov$endpoint)) {
    s <- dplyr::filter(seg_cov, endpoint == ep) |> dplyr::arrange(dplyr::desc(N_seg))
    lines <- c(lines, paste0("## ", ep),
      paste0("- ", nrow(s), " segments observed; N=", sum(s$N_seg), " entities over ",
             max(s$n_periods), " period(s)"))
    top <- head(s, 12)
    lines <- c(lines, paste0("  - `", top$segment, "`  N=", top$N_seg, " fields=", top$n_fields))
    sl <- dplyr::filter(slices, endpoint == ep)
    if (nrow(sl)) {
      lines <- c(lines, "- rare slices censused (observed / population):",
        paste0("  - ", sl$slice, ": ", sl$observed, " / ", pint(sl$population)))
    }
    lines <- c(lines, "")
  }
  lines <- c(lines, "## Field drivers: conditional prevalence \u03b8(field | segment)",
    "Top segment per field, ranked by concentration (conditional \u2212 marginal).",
    "Census over-samples rare strata: conditional \u03b8 is unbiased; sample marginal is inflated; population marginal = pop-share \u00d7 \u03b8.")
  d <- head(drivers, 18)
  lines <- c(lines, paste0("- `", d$endpoint, ".", d$path, "` \u2192 `", d$segment,
    "` \u03b8=", fmt(d$theta_cond), " (n=", d$N_seg, "), marginal=", fmt(d$theta_marg)), "")
  lines <- c(lines, "## New fields this period",
    if (nrow(new_fields)) paste0("- `", new_fields$endpoint, ".", new_fields$path,
      "` first seen in `", new_fields$segment, "`") else "- none", "")
  lines <- c(lines, "## Conditional removals (deterministic field absent where segment was sampled)",
    if (nrow(removed)) paste0("- `", removed$endpoint, ".", removed$path, "` in `", removed$segment,
      "` prior \u03b8=", fmt(removed$theta_prior), ", absent across n=", removed$n_now,
      " sampled this period") else "- none")
  paste(lines, collapse = "\n")
}

bayes_period <- function(counts_path, state_dir = "data-raw/api_monitor/state",
                         remove_prev = 0.8, update_baseline = FALSE) {
  cur <- readr::read_tsv(counts_path, show_col_types = FALSE)
  pops <- read_pops(counts_path)
  st <- read_prev_state(state_dir)
  period_id <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  n_period_seg <- cur |> dplyr::distinct(endpoint, segment, n) |> dplyr::rename(n_now = n)

  prior <- st$fields |> dplyr::select(endpoint, segment, path, k_prior = k_cum)
  prior_field <- st$fields |> dplyr::filter(k_cum > 0) |> dplyr::distinct(endpoint, path) |>
    dplyr::mutate(known = TRUE)

  fields <- dplyr::full_join(
    st$fields |> dplyr::select(endpoint, segment, path, type, k_cum, periods_seen, last_period),
    cur |> dplyr::transmute(endpoint, segment, path, type_new = type, k_new = k),
    by = c("endpoint", "segment", "path")
  ) |>
    dplyr::mutate(
      type = dplyr::coalesce(type_new, type),
      seen_now = !is.na(k_new) & k_new > 0,
      k_cum = dplyr::coalesce(k_cum, 0) + dplyr::coalesce(k_new, 0),
      periods_seen = dplyr::coalesce(periods_seen, 0L) + as.integer(seen_now),
      last_period = ifelse(seen_now, period_id, last_period)
    )

  periods_new <- n_period_seg |>
    dplyr::transmute(period = period_id, endpoint, segment, n = n_now, date = period_id)
  periods_all <- dplyr::bind_rows(st$periods, periods_new)
  Nseg <- periods_all |> dplyr::group_by(endpoint, segment) |>
    dplyr::summarise(N_seg = sum(n), n_periods = dplyr::n(), .groups = "drop")

  model <- fields |>
    dplyr::left_join(Nseg, by = c("endpoint", "segment")) |>
    dplyr::mutate(
      theta_cond = cond_prevalence(k_cum, N_seg),
      lo = stats::qbeta(0.025, 0.5 + k_cum, 0.5 + N_seg - k_cum),
      hi = stats::qbeta(0.975, 0.5 + k_cum, 0.5 + N_seg - k_cum)
    )

  Ntot <- Nseg |> dplyr::group_by(endpoint) |> dplyr::summarise(N_tot = sum(N_seg), .groups = "drop")
  marg <- model |> dplyr::group_by(endpoint, path) |>
    dplyr::summarise(k_tot = sum(k_cum), .groups = "drop") |>
    dplyr::left_join(Ntot, by = "endpoint") |>
    dplyr::mutate(theta_marg = k_tot / N_tot)

  drivers <- model |>
    dplyr::group_by(endpoint, path) |>
    dplyr::slice_max(theta_cond, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::left_join(marg |> dplyr::select(endpoint, path, theta_marg), by = c("endpoint", "path")) |>
    dplyr::mutate(concentration = theta_cond - theta_marg) |>
    dplyr::arrange(dplyr::desc(concentration), dplyr::desc(theta_cond))

  new_fields <- fields |>
    dplyr::filter(seen_now) |>
    dplyr::left_join(prior_field, by = c("endpoint", "path")) |>
    dplyr::filter(is.na(known)) |>
    dplyr::group_by(endpoint, path) |>
    dplyr::slice_max(k_new, n = 1, with_ties = FALSE) |>
    dplyr::ungroup() |>
    dplyr::select(endpoint, segment, path)

  removed <- fields |>
    dplyr::filter(!seen_now) |>
    dplyr::inner_join(prior, by = c("endpoint", "segment", "path")) |>
    dplyr::inner_join(Nseg |> dplyr::select(endpoint, segment, N_prior = N_seg), by = c("endpoint", "segment")) |>
    dplyr::inner_join(n_period_seg, by = c("endpoint", "segment")) |>
    dplyr::mutate(theta_prior = cond_prevalence(k_prior, N_prior - n_now)) |>
    dplyr::filter(k_prior > 0, theta_prior >= remove_prev, n_now > 0) |>
    dplyr::select(endpoint, segment, path, theta_prior, n_now) |>
    dplyr::arrange(dplyr::desc(theta_prior))

  seg_cov <- model |>
    dplyr::group_by(endpoint, segment) |>
    dplyr::summarise(N_seg = dplyr::first(N_seg), n_periods = dplyr::first(n_periods),
                     n_fields = sum(k_cum > 0), .groups = "drop")

  ptot <- pops |> dplyr::filter(state == "_total") |> dplyr::pull(population)
  slice_obs <- function(ep, pred, lbl, key) {
    segs <- seg_cov |> dplyr::filter(endpoint == ep, pred(segment))
    pop <- pops |> dplyr::filter(state == key) |> dplyr::pull(population)
    tibble::tibble(endpoint = ep, slice = lbl, observed = sum(segs$N_seg),
                   population = if (length(pop)) pop[1] else NA_real_)
  }
  slices <- dplyr::bind_rows(
    slice_obs("enhet", function(s) seg_state(s) == "konkurs", "konkurs", "konkurs"),
    slice_obs("enhet", function(s) seg_state(s) == "tvangsavvikling", "tvangsavvikling", "tvangsavvikling"),
    slice_obs("enhet", function(s) seg_state(s) == "avvikling", "avvikling", "avvikling"),
    slice_obs("enhet", function(s) seg_form(s) == "NUF", "NUF (foreign)", "NUF")
  ) |> dplyr::filter(observed > 0)

  report <- build_cond_report(seg_cov, slices, drivers, new_fields, removed, period_id)
  out_fields <- model |> dplyr::select(endpoint, segment, path, type, k_cum, periods_seen, last_period)
  if (update_baseline || nrow(st$fields) == 0) write_prev_state(state_dir, out_fields, periods_all)

  list(report = report, model = model, drivers = drivers, seg_cov = seg_cov, slices = slices,
       new_fields = new_fields, removed = removed, fields = out_fields, periods = periods_all,
       total_population = if (length(ptot)) ptot[1] else NA_real_,
       drift = nrow(new_fields) > 0 || nrow(removed) > 0)
}
