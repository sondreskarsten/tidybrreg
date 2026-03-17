#' Compute daily entry and exit flows
#'
#' Calculate daily counts of entity registrations (entries) and
#' deletions (exits) classified by industry (NACE code) and
#' geography (municipality code). Combines two data sources:
#'
#' 1. **Bulk download** — the `registration_date` column provides
#'    the complete entry history for all currently-active entities.
#'    No exit information (deleted entities are purged from the
#'    nightly bulk export).
#'
#' 2. **CDC stream** — `Ny` (new) and `Sletting` (deleted) events
#'    from the [brreg_updates()] endpoint, enriched with entity
#'    attributes from the bulk data. Provides both entries and exits
#'    with real event timestamps.
#'
#' When only bulk data is provided (no `updates`), only entries
#' are computed. Pass CDC data to unlock exit counts.
#'
#' @section Entry vs. founding date:
#' This function uses `registration_date`
#' (registreringsdatoEnhetsregisteret), NOT `founding_date`
#' (stiftelsesdato). Registration date is when the entity entered
#' the registry. Founding date can precede registration by months
#' (AS companies) or years (associations). See vignette for
#' comparison with SSB business demography definitions.
#'
#' @param data A tibble from [brreg_download()] or a snapshot
#'   read via [read_parquet_safe()]. Must contain `org_nr`,
#'   `registration_date`, `nace_1`, and `municipality_code`.
#' @param updates Optional. A tibble from [brreg_updates()] with
#'   CDC events. When provided, entries and exits from the CDC
#'   stream are enriched with attributes from `data` and merged
#'   with the registration-date-based entries.
#' @param by Character vector of grouping columns. Default
#'   `c("nace_1", "municipality_code")`. Use `NULL` for national
#'   totals, or any column present in `data`.
#' @param from,to Date range for the output. `NULL` defaults to
#'   the range of observed events.
#' @param legal_form Optional character vector of legal form codes
#'   to include (e.g. `c("AS", "ENK")`). `NULL` includes all.
#'
#' @returns A tibble with columns: `date` (Date), grouping columns
#'   from `by`, `entries` (integer), `exits` (integer), `net`
#'   (integer: entries - exits). An attribute `flow_source` records
#'   which data sources contributed.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_download()] to get bulk data,
#'   [brreg_updates()] to get CDC events,
#'   [brreg_series()] for snapshot-based time series,
#'   [as_brreg_tsibble()] for tsibble conversion.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' entities <- brreg_download()
#' flows <- brreg_flows(entities)
#'
#' # With CDC exits
#' cdc <- brreg_updates(since = "2026-01-01", size = 10000)
#' flows <- brreg_flows(entities, updates = cdc)
#'
#' # Monthly by NACE section
#' flows |>
#'   dplyr::mutate(month = format(date, "%Y-%m"),
#'                 nace_section = substr(nace_1, 1, 2)) |>
#'   dplyr::summarise(entries = sum(entries), exits = sum(exits),
#'                    .by = c(month, nace_section))
#' }
brreg_flows <- function(data,
                         updates  = NULL,
                         by       = c("nace_1", "municipality_code"),
                         from     = NULL,
                         to       = NULL,
                         legal_form = NULL) {

  required <- c("org_nr", "registration_date")
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort("Missing required columns: {.val {missing_cols}}")
  }
  by <- intersect(by %||% character(), names(data))

  if (!is.null(legal_form)) {
    data <- data[data$legal_form %in% legal_form, , drop = FALSE]
  }

  entries_hist <- compute_entries_from_bulk(data, by)

  exits_cdc <- NULL
  entries_cdc <- NULL
  sources <- "registration_date"

  if (!is.null(updates) && nrow(updates) > 0) {
    enriched <- enrich_cdc(updates, data, by)
    entries_cdc <- enriched$entries
    exits_cdc <- enriched$exits
    sources <- c(sources, "cdc")
  }

  all_entries <- dplyr::bind_rows(entries_hist, entries_cdc)
  all_exits <- exits_cdc

  group_cols <- c("date", by)

  entry_counts <- all_entries |>
    dplyr::summarise(entries = dplyr::n(), .by = dplyr::all_of(group_cols))

  exit_counts <- if (!is.null(all_exits) && nrow(all_exits) > 0) {
    all_exits |>
      dplyr::summarise(exits = dplyr::n(), .by = dplyr::all_of(group_cols))
  } else {
    NULL
  }

  result <- if (!is.null(exit_counts)) {
    dplyr::full_join(entry_counts, exit_counts, by = group_cols)
  } else {
    entry_counts |> dplyr::mutate(exits = 0L)
  }

  result$entries[is.na(result$entries)] <- 0L
  result$exits[is.na(result$exits)] <- 0L
  result$net <- result$entries - result$exits

  from <- from %||% min(result$date, na.rm = TRUE)
  to <- to %||% max(result$date, na.rm = TRUE)
  result <- result[result$date >= as.Date(from) & result$date <= as.Date(to), , drop = FALSE]

  result <- result[order(result$date), ]
  attr(result, "flow_source") <- sources
  attr(result, "by") <- by
  attr(result, "brreg_panel_meta") <- list(index = "date", key = by, frequency = "day")
  result
}


#' Extract daily entry counts from bulk registration_date
#' @keywords internal
compute_entries_from_bulk <- function(data, by) {
  keep_cols <- c("registration_date", by)
  keep_cols <- intersect(keep_cols, names(data))

  out <- data[!is.na(data$registration_date), keep_cols, drop = FALSE]
  names(out)[names(out) == "registration_date"] <- "date"
  out
}


#' Enrich CDC events with entity attributes from bulk data
#' @keywords internal
enrich_cdc <- function(updates, bulk, by) {
  attr_cols <- unique(c("org_nr", by))
  attr_cols <- intersect(attr_cols, names(bulk))

  lookup <- bulk[, attr_cols, drop = FALSE]
  lookup <- lookup[!duplicated(lookup$org_nr), ]

  ny <- updates[updates$change_type == "Ny", , drop = FALSE]
  entries <- if (nrow(ny) > 0) {
    merged <- dplyr::left_join(ny, lookup, by = "org_nr")
    merged$date <- as.Date(merged$timestamp)
    merged[, intersect(c("date", by), names(merged)), drop = FALSE]
  } else {
    NULL
  }

  slett_types <- c("Sletting", "Fjernet")
  slett <- updates[updates$change_type %in% slett_types, , drop = FALSE]
  exits <- if (nrow(slett) > 0) {
    merged <- dplyr::left_join(slett, lookup, by = "org_nr")
    merged$date <- as.Date(merged$timestamp)
    merged[, intersect(c("date", by), names(merged)), drop = FALSE]
  } else {
    NULL
  }

  list(entries = entries, exits = exits)
}
