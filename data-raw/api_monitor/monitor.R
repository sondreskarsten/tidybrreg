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

build_sources_report <- function(diff, sources, base) {
  if (is.null(base)) return("## API changelog and notices\nFirst run — source baseline written.")
  oc <- diff$openapi_changes
  rss <- diff$new_rss
  com <- diff$new_commits
  paste(c(
    "## OpenAPI changelog",
    if (nrow(oc)) paste0("- ", oc$api, ": ", oc$change, " — ", oc$detail) else "- no change",
    "",
    "## Notices (driftsmeldinger / nyheter)",
    if (nrow(rss)) paste0("- [", rss$feed, "] ", rss$title) else "- none",
    "",
    "## openAPI repo commits",
    if (nrow(com)) paste0("- ", com$title) else "- none"
  ), collapse = "\n")
}

sources_run <- function(state_dir = "data-raw/api_monitor/state", update_baseline = FALSE) {
  sources <- collect_sources()
  p <- file.path(state_dir, "source_baseline.json")
  base <- if (file.exists(p)) jsonlite::read_json(p, simplifyVector = FALSE) else NULL
  diff <- if (is.null(base)) {
    list(new_commits = sources$commits[0, ], new_rss = sources$rss[0, ], openapi_changes = tibble::tibble())
  } else {
    diff_sources(base, sources)
  }
  if (update_baseline || is.null(base)) {
    dir.create(state_dir, showWarnings = FALSE, recursive = TRUE)
    jsonlite::write_json(sources, p, pretty = TRUE, auto_unbox = TRUE)
  }
  drift <- !is.null(base) && (nrow(diff$new_commits) > 0 || nrow(diff$new_rss) > 0 || nrow(diff$openapi_changes) > 0)
  list(report = build_sources_report(diff, sources, base), drift = drift)
}
