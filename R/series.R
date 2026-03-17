#' Compute aggregate time series from snapshots
#'
#' Produce period-level summary statistics from the snapshot store
#' for any combination of variables and summary functions. Returns
#' a tibble suitable for ggplot2 or [as_brreg_tsibble()] conversion.
#'
#' @param .vars Character vector of column names to aggregate.
#'   `NULL` (default) counts entities per period.
#' @param .fns Named list of summary functions applied to each
#'   column in `.vars`. Default: `list(total = \(x) sum(x, na.rm = TRUE))`.
#'   Use `list(avg = mean, sd = sd)` for multiple summaries.
#'   Output columns are named `{variable}_{function}`.
#' @param by Character vector of grouping column names
#'   (e.g. `"nace_1"`, `c("legal_form", "municipality_code")`).
#'   `NULL` for national totals.
#' @param frequency One of `"year"`, `"quarter"`, `"month"`.
#' @inheritParams brreg_panel
#' @param type One of `"enheter"`, `"underenheter"`, `"roller"`.
#' @param label Logical. Translate group codes to English labels.
#'
#' @returns A tibble with `period` (character), optional grouping
#'   columns, and one column per variable-function combination.
#'   Attribute `brreg_panel_meta` records metadata for
#'   [as_brreg_tsibble()] conversion.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_panel()] for entity-level panels,
#'   [as_brreg_tsibble()] for tsibble conversion.
#'
#' @export
#' @examplesIf interactive() && requireNamespace("arrow", quietly = TRUE)
#' \donttest{
#' brreg_series(.vars = "employees", by = "legal_form")
#'
#' brreg_series(.vars = "employees",
#'              .fns = list(avg = mean, total = sum),
#'              by = "nace_1")
#' }
brreg_series <- function(.vars = NULL,
                          .fns = list(total = \(x) sum(x, na.rm = TRUE)),
                          by = NULL,
                          frequency = c("year", "quarter", "month"),
                          from = NULL, to = NULL,
                          type = c("enheter", "underenheter", "roller"),
                          label = FALSE) {
  frequency <- match.arg(frequency)
  type <- match.arg(type)

  snaps <- brreg_snapshots(type)
  if (nrow(snaps) < 1) {
    cli::cli_abort("No snapshots found for {.val {type}}.")
  }

  available <- sort(snaps$snapshot_date)
  from <- as.Date(from %||% min(available))
  to <- as.Date(to %||% max(available))

  targets <- switch(frequency,
    year    = generate_year_targets(from, to),
    quarter = generate_quarter_targets(from, to),
    month   = generate_month_targets(from, to)
  )

  mapping <- resolve_snapshot_dates(available, targets)
  if (nrow(mapping) == 0) {
    cli::cli_abort("No snapshots available for the requested period range.")
  }

  read_cols <- unique(c("org_nr", .vars, by))

  chunks <- lapply(seq_len(nrow(mapping)), function(i) {
    snap_date <- mapping$snapshot_date[i]
    path <- snaps$path[snaps$snapshot_date == snap_date]
    dat <- read_parquet_safe(path)
    keep <- intersect(read_cols, names(dat))
    dat <- dat[, keep, drop = FALSE]
    dat$period <- mapping$period[i]
    dat
  })
  panel <- dplyr::bind_rows(chunks)

  grp <- c("period", by)

  if (is.null(.vars)) {
    result <- panel |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grp))) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop")
  } else {
    result <- panel |>
      dplyr::group_by(dplyr::across(dplyr::all_of(grp))) |>
      dplyr::summarise(
        dplyr::across(dplyr::all_of(.vars), .fns, .names = "{.col}_{.fn}"),
        .groups = "drop"
      )
  }

  if (label && !is.null(by)) result <- brreg_label(result)

  attr(result, "brreg_panel_meta") <- list(
    index = "period", key = by %||% character(), frequency = frequency
  )
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
