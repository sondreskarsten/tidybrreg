#' Compute aggregate time series from snapshots
#'
#' Produce period-level summary statistics from the snapshot store.
#' Returns a tibble suitable for ggplot2 or tsibble conversion.
#'
#' @param metric One of:
#'   - `"count"`: number of entities per period
#'   - `"employees"`: total employees per period
#'   - `"entries"`: new registrations per period (requires 2+ snapshots)
#'   - `"exits"`: disappearances per period (requires 2+ snapshots)
#' @param by Optional grouping column name: `"nace_1"`, `"legal_form"`,
#'   `"municipality_code"`, or `NULL` for national totals.
#' @param frequency One of `"year"`, `"quarter"`, `"month"`.
#' @param from,to Date range.
#' @param type One of `"enheter"` or `"underenheter"`.
#' @param label Logical. Translate group codes to English labels.
#'
#' @returns A tibble with columns: `period`, optional grouping column,
#'   `value`.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_panel()] for entity-level panels.
#'
#' @export
#' @examplesIf interactive() && requireNamespace("arrow", quietly = TRUE)
#' \donttest{
#' brreg_series("count", by = "legal_form")
#' }
brreg_series <- function(metric = c("count", "employees", "entries", "exits"),
                          by = NULL,
                          frequency = c("year", "quarter", "month"),
                          from = NULL, to = NULL,
                          type = c("enheter", "underenheter"),
                          label = FALSE) {
  metric <- match.arg(metric)
  frequency <- match.arg(frequency)
  type <- match.arg(type)

  if (metric %in% c("entries", "exits")) {
    return(series_flow(metric, by, frequency, from, to, type, label))
  }

  panel_cols <- c(if (!is.null(by)) by, if (metric == "employees") "employees")
  panel <- brreg_panel(
    frequency = frequency, cols = panel_cols,
    from = from, to = to, type = type, label = FALSE
  )

  grp <- if (!is.null(by)) c("period", by) else "period"

  result <- switch(metric,
    count = panel |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grp))) |>
      dplyr::summarise(value = dplyr::n(), .groups = "drop"),
    employees = panel |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grp))) |>
      dplyr::summarise(value = sum(.data$employees, na.rm = TRUE), .groups = "drop")
  )

  if (label && !is.null(by)) result <- brreg_label(result)
  result
}


#' Compute entry/exit flow series from consecutive snapshot diffs
#' @keywords internal
series_flow <- function(metric, by, frequency, from, to, type, label) {
  snaps <- brreg_snapshots(type)
  if (nrow(snaps) < 2) {
    cli::cli_abort("Entry/exit series requires at least 2 snapshots.")
  }

  available <- sort(snaps$snapshot_date)
  from <- from %||% min(available)
  to <- to %||% max(available)
  from <- as.Date(from)
  to <- as.Date(to)

  available <- available[available >= from & available <= to]
  if (length(available) < 2) {
    cli::cli_abort("Need at least 2 snapshots in the [{from}, {to}] range.")
  }

  pairs <- tibble::tibble(
    date_from = available[-length(available)],
    date_to = available[-1]
  )

  target_col <- if (metric == "entries") "entry" else "exit"
  all_events <- vector("list", nrow(pairs))

  for (i in seq_len(nrow(pairs))) {
    ev <- brreg_events(pairs$date_from[i], pairs$date_to[i],
                        cols = by, type = type)
    ev <- ev[ev$event_type == target_col, , drop = FALSE]

    if (!is.null(by) && nrow(ev) > 0) {
      snap <- read_parquet_safe(snaps$path[snaps$snapshot_date == pairs$date_to[i]])
      ev <- dplyr::left_join(ev, snap[, c("org_nr", by), drop = FALSE],
                              by = "org_nr")
    }
    ev$period_date <- pairs$date_to[i]
    all_events[[i]] <- ev
  }

  events <- dplyr::bind_rows(all_events)
  if (nrow(events) == 0) {
    cols <- c("period", if (!is.null(by)) by, "value")
    return(tibble::tibble(!!!stats::setNames(
      replicate(length(cols), character(0), simplify = FALSE), cols
    )))
  }

  events$period <- format_period(events$period_date, frequency)
  grp <- if (!is.null(by)) c("period", by) else "period"

  result <- events |>
    dplyr::group_by(dplyr::across(dplyr::all_of(grp))) |>
    dplyr::summarise(value = dplyr::n(), .groups = "drop")

  if (label && !is.null(by)) result <- brreg_label(result)
  result
}


#' Format a date as a period label
#' @keywords internal
format_period <- function(date, frequency) {
  switch(frequency,
    year    = format(date, "%Y"),
    quarter = paste0(format(date, "%Y"), "-Q", ceiling(as.integer(format(date, "%m")) / 3)),
    month   = format(date, "%Y-%m")
  )
}
