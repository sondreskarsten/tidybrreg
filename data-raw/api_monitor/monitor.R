suppressPackageStartupMessages({
  library(httr2)
  library(jsonlite)
  library(xml2)
  library(rvest)
  library(dplyr)
  library(tibble)
  library(readr)
  library(purrr)
})

`%||%` <- function(a, b) if (is.null(a)) b else a

mon_user_agent <- function() {
  "tidybrreg-api-monitor (https://github.com/sondreskarsten/tidybrreg)"
}

mon_realm <- function(url) sub("^https?://([^/]+)/.*$", "\\1", url)

mon_openapi_specs <- function() {
  c(enhetsregisteret = "https://raw.githubusercontent.com/brreg/openAPI/master/specs/enhetsregisteret.json")
}

mon_commit_feed <- function() "https://github.com/brreg/openAPI/commits/master.atom"

mon_rss_feeds <- function() {
  c(
    driftsmeldinger = "https://www.brreg.no/driftsmeldinger/feed/",
    nyheter         = "https://www.brreg.no/nyhetsarkiv/feed/"
  )
}

mon_pkg_version <- function(path = "DESCRIPTION") {
  unname(read.dcf(path, fields = "Version")[1, 1])
}

extract_changelog <- function(description) {
  if (is.null(description) || !nzchar(description) || !grepl("Endringslogg", description)) {
    return(tibble::tibble(versjon = character(), dato = character(), endring = character()))
  }
  tabs <- rvest::html_table(rvest::html_elements(xml2::read_html(description), "table"))
  hit <- purrr::detect(tabs, ~ any(grepl("Versjon", names(.x), ignore.case = TRUE)))
  if (is.null(hit)) return(tibble::tibble(versjon = character(), dato = character(), endring = character()))
  hit |>
    dplyr::rename_with(tolower) |>
    dplyr::select(dplyr::any_of(c("versjon", "dato", "endring"))) |>
    dplyr::mutate(dplyr::across(dplyr::everything(), as.character))
}

fetch_openapi <- function(specs = mon_openapi_specs(), user_agent = mon_user_agent()) {
  purrr::imap(specs, function(url, api) {
    raw <- httr2::request(url) |>
      httr2::req_user_agent(user_agent) |>
      httr2::req_throttle(rate = 4, realm = mon_realm(url)) |>
      httr2::req_perform() |>
      httr2::resp_body_string()
    spec <- jsonlite::fromJSON(raw, simplifyVector = FALSE)
    list(
      version = spec$info$version %||% NA_character_,
      hash = substr(rlang::hash(raw), 1, 16),
      changelog = extract_changelog(spec$info$description)
    )
  })
}

fetch_commits <- function(feed_url = mon_commit_feed(), n = 15, user_agent = mon_user_agent()) {
  x <- httr2::request(feed_url) |>
    httr2::req_user_agent(user_agent) |>
    httr2::req_throttle(rate = 4, realm = mon_realm(feed_url)) |>
    httr2::req_perform() |>
    httr2::resp_body_xml()
  xml2::xml_ns_strip(x)
  entries <- head(xml2::xml_find_all(x, "//entry"), n)
  tibble::tibble(
    commit_id = xml2::xml_text(xml2::xml_find_first(entries, ".//id")),
    title = trimws(xml2::xml_text(xml2::xml_find_first(entries, ".//title"))),
    updated = xml2::xml_text(xml2::xml_find_first(entries, ".//updated"))
  )
}

fetch_rss <- function(feeds = mon_rss_feeds(), n = 10, user_agent = mon_user_agent()) {
  purrr::imap_dfr(feeds, function(url, feed) {
    x <- httr2::request(url) |>
      httr2::req_user_agent(user_agent) |>
      httr2::req_throttle(rate = 4, realm = mon_realm(url)) |>
      httr2::req_perform() |>
      httr2::resp_body_xml()
    items <- head(xml2::xml_find_all(x, "//item"), n)
    tibble::tibble(
      feed = feed,
      item_id = xml2::xml_text(xml2::xml_find_first(items, "guid|link")),
      title = trimws(xml2::xml_text(xml2::xml_find_first(items, "title"))),
      pubdate = xml2::xml_text(xml2::xml_find_first(items, "pubDate"))
    )
  })
}

collect_sources <- function() {
  list(
    collected_at = format(Sys.time(), tz = "UTC", usetz = TRUE),
    openapi = fetch_openapi(),
    commits = fetch_commits(),
    rss = fetch_rss()
  )
}

mon_paths <- function(state_dir) {
  list(
    schemas = file.path(state_dir, "schema_baseline.tsv"),
    sources = file.path(state_dir, "source_baseline.json")
  )
}

read_baseline <- function(state_dir) {
  p <- mon_paths(state_dir)
  if (!file.exists(p$schemas) || !file.exists(p$sources)) return(NULL)
  list(
    schemas = readr::read_tsv(p$schemas, show_col_types = FALSE),
    sources = jsonlite::read_json(p$sources, simplifyVector = FALSE)
  )
}

write_baseline <- function(state_dir, schemas, sources) {
  dir.create(state_dir, showWarnings = FALSE, recursive = TRUE)
  p <- mon_paths(state_dir)
  readr::write_tsv(dplyr::arrange(schemas, endpoint, path), p$schemas)
  jsonlite::write_json(sources, p$sources, pretty = TRUE, auto_unbox = TRUE)
  invisible(p)
}

diff_schema <- function(old, new) {
  ok <- old |> dplyr::mutate(key = paste(endpoint, path))
  nk <- new |> dplyr::mutate(key = paste(endpoint, path))
  added <- nk |> dplyr::anti_join(ok, by = "key") |>
    dplyr::transmute(endpoint, path, change = "added", detail = type)
  removed <- ok |> dplyr::anti_join(nk, by = "key") |>
    dplyr::transmute(endpoint, path, change = "removed", detail = type)
  changed <- nk |> dplyr::inner_join(ok, by = "key", suffix = c("_new", "_old")) |>
    dplyr::filter(type_new != type_old) |>
    dplyr::transmute(endpoint = endpoint_new, path = path_new, change = "type_changed",
                     detail = paste0(type_old, " -> ", type_new))
  dplyr::bind_rows(added, removed, changed) |> dplyr::arrange(endpoint, path)
}

diff_sources <- function(old, new) {
  old_commit_ids <- purrr::map_chr(old$commits, ~ .x$commit_id %||% NA_character_)
  new_commits <- dplyr::filter(new$commits, !commit_id %in% old_commit_ids)

  old_rss_ids <- purrr::map_chr(old$rss, ~ .x$item_id %||% NA_character_)
  new_rss <- dplyr::filter(new$rss, !item_id %in% old_rss_ids)

  openapi_changes <- purrr::imap_dfr(new$openapi, function(spec, api) {
    o <- old$openapi[[api]]
    if (is.null(o)) return(tibble::tibble(api = api, change = "new spec", detail = spec$version %||% ""))
    if (!identical(spec$hash, o$hash %||% "")) {
      old_rows <- purrr::map_chr(o$changelog %||% list(),
                                 ~ paste(.x$versjon %||% "", .x$dato %||% "", .x$endring %||% ""))
      new_rows <- spec$changelog |> dplyr::transmute(r = paste(versjon, dato, endring)) |> dplyr::pull(r)
      added_rows <- setdiff(new_rows, old_rows)
      detail <- if (length(added_rows)) paste(added_rows, collapse = "; ")
                else paste0("spec changed (", o$version %||% "?", " -> ", spec$version %||% "?", ")")
      return(tibble::tibble(api = api, change = "spec changed", detail = detail))
    }
    tibble::tibble()
  })

  list(new_commits = new_commits, new_rss = new_rss, openapi_changes = openapi_changes)
}

build_report <- function(schema_diff, source_diff, sources, base) {
  baseline_at <- if (is.null(base)) "none (first run)" else base$sources$collected_at %||% "unknown"
  lines <- c(
    "# tidybrreg API monitor report",
    paste0("Checked: ", sources$collected_at),
    paste0("Baseline: ", baseline_at),
    ""
  )
  if (is.null(base)) {
    return(paste(c(lines, "First run — baseline written, no diff."), collapse = "\n"))
  }
  oc <- source_diff$openapi_changes
  lines <- c(lines, "## OpenAPI specs",
             if (nrow(oc)) paste0("- ", oc$api, ": ", oc$change, " — ", oc$detail) else "- no change")
  lines <- c(lines, "", "## New brreg notices (driftsmeldinger / nyheter)",
             if (nrow(source_diff$new_rss)) paste0("- [", source_diff$new_rss$feed, "] ", source_diff$new_rss$title) else "- none")
  lines <- c(lines, "", "## New openAPI repo commits",
             if (nrow(source_diff$new_commits)) paste0("- ", source_diff$new_commits$title) else "- none")
  lines <- c(lines, "", "## Empirical JSON schema drift",
             if (nrow(schema_diff)) paste0("- ", schema_diff$change, ": `", schema_diff$endpoint, ".", schema_diff$path, "` (", schema_diff$detail, ")") else "- no change")
  paste(lines, collapse = "\n")
}

build_news <- function(schema_diff, source_diff, sources, base, version = mon_pkg_version()) {
  baseline_at <- if (is.null(base)) "first run" else base$sources$collected_at %||% "unknown"
  has_change <- !is.null(base) &&
    (nrow(schema_diff) > 0 || nrow(source_diff$openapi_changes) > 0 ||
       nrow(source_diff$new_rss) > 0 || nrow(source_diff$new_commits) > 0)
  if (!has_change) {
    return(paste0("## Brønnøysund API changes\n\nNo API changes detected since baseline (", baseline_at, ")."))
  }
  detected <- c(
    if (nrow(source_diff$openapi_changes)) paste0("* ", source_diff$openapi_changes$api, " spec: ", source_diff$openapi_changes$detail, "."),
    if (nrow(schema_diff)) paste0("* JSON ", schema_diff$change, ": `", schema_diff$endpoint, ".", schema_diff$path, "`."),
    if (nrow(source_diff$new_rss)) paste0("* Notice (", source_diff$new_rss$feed, "): ", source_diff$new_rss$title, ".")
  )
  paste(c(
    "## Brønnøysund API changes",
    "",
    paste0("Detected since last release (baseline ", baseline_at, "):"),
    "",
    detected,
    "",
    paste0("### Addressed in tidybrreg ", version),
    "* [ ] (describe how the package handles each change above, or note no action needed)"
  ), collapse = "\n")
}

read_schema_tsv <- function(path) {
  readr::read_tsv(path, show_col_types = FALSE)
}

api_monitor_run <- function(schema_path, state_dir = "data-raw/api_monitor/state", update_baseline = FALSE) {
  schemas <- read_schema_tsv(schema_path)
  sources <- collect_sources()
  base <- read_baseline(state_dir)
  if (is.null(base)) {
    schema_diff <- tibble::tibble(endpoint = character(), path = character(), change = character(), detail = character())
    source_diff <- list(new_commits = sources$commits[0, ], new_rss = sources$rss[0, ], openapi_changes = tibble::tibble())
  } else {
    schema_diff <- diff_schema(base$schemas, schemas)
    source_diff <- diff_sources(base$sources, sources)
  }
  report <- build_report(schema_diff, source_diff, sources, base)
  news <- build_news(schema_diff, source_diff, sources, base)
  if (update_baseline || is.null(base)) write_baseline(state_dir, schemas, sources)
  list(report = report, news = news, schema_diff = schema_diff, source_diff = source_diff,
       schemas = schemas, sources = sources, drift = nrow(schema_diff) > 0 ||
         nrow(source_diff$openapi_changes) > 0 || nrow(source_diff$new_rss) > 0 || nrow(source_diff$new_commits) > 0)
}
