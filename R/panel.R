#' Construct a firm-period panel from accumulated snapshots
#'
#' Build an unbalanced firm × period panel from the Hive-partitioned
#' snapshot store. For each target period, selects the most recent
#' prior snapshot (LOCF). Requires at least two snapshots saved via
#' [brreg_snapshot()] or [brreg_import()].
#'
#' @param frequency One of `"year"` (default), `"quarter"`, `"month"`,
#'   or `"custom"`. For `"custom"`, supply target dates via `dates`.
#' @param cols Character vector of column names to include. `NULL`
#'   (default) returns all columns mapped by [field_dict].
#' @param from,to Start and end dates for the panel. `NULL` defaults
#'   to the range of available snapshots.
#' @param dates Date vector for `frequency = "custom"`.
#' @param max_gap Integer. Maximum number of periods a snapshot may
#'   carry forward via LOCF. `NULL` (default) carries forward
#'   indefinitely. Set `max_gap = 2` to prevent a quarterly snapshot
#'   from representing a firm as active 3+ quarters after its last
#'   observation.
#' @param type One of `"enheter"` or `"underenheter"`.
#' @param label Logical. If `TRUE`, apply [brreg_label()] to the
#'   result.
#'
#' @returns A tibble with columns: `org_nr`, `period` (character label
#'   for the period), `snapshot_date` (the actual snapshot used),
#'   plus requested `cols`. Attribute `date_mapping` records which
#'   snapshot was used for each period.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_snapshot()] to accumulate snapshots,
#'   [brreg_events()] for change detection between snapshots.
#'
#' @export
#' @examplesIf interactive() && requireNamespace("arrow", quietly = TRUE)
#' \donttest{
#' # Annual panel of all entities
#' panel <- brreg_panel()
#'
#' # Monthly panel for specific columns
#' panel <- brreg_panel("month", cols = c("employees", "nace_1", "legal_form"))
#' }
brreg_panel <- function(frequency = c("year", "quarter", "month", "custom"),
                         cols = NULL,
                         from = NULL,
                         to = NULL,
                         dates = NULL,
                         max_gap = NULL,
                         type = c("enheter", "underenheter", "roller"),
                         label = FALSE) {
  frequency <- match.arg(frequency)
  type <- match.arg(type)

  snaps <- brreg_snapshots(type)
  if (nrow(snaps) < 2) {
    cli::cli_abort(c(
      "Panel construction requires at least 2 snapshots.",
      "i" = "Found {nrow(snaps)} for {.val {type}}. Run {.code brreg_snapshot()} to add more."
    ))
  }

  available <- snaps$snapshot_date
  from <- from %||% min(available)
  to <- to %||% max(available)
  from <- as.Date(from)
  to <- as.Date(to)

  targets <- switch(frequency,
    year    = generate_year_targets(from, to),
    quarter = generate_quarter_targets(from, to),
    month   = generate_month_targets(from, to),
    custom  = as.Date(dates)
  )

  mapping <- resolve_snapshot_dates(available, targets)
  if (nrow(mapping) == 0) {
    cli::cli_abort("No snapshots available for the requested period range.")
  }

  if (!is.null(max_gap)) {
    mapping$gap <- as.integer(difftime(mapping$target_date, mapping$snapshot_date, units = "days"))
    period_days <- switch(frequency,
      year = 365L, quarter = 92L, month = 31L, custom = max(mapping$gap, na.rm = TRUE)
    )
    max_days <- as.integer(max_gap) * period_days
    mapping <- mapping[mapping$gap <= max_days, , drop = FALSE]
    mapping$gap <- NULL
    if (nrow(mapping) == 0) {
      cli::cli_abort(c(
        "No periods remain after applying {.arg max_gap = {max_gap}}.",
        "i" = "Increase {.arg max_gap} or add more snapshots."
      ))
    }
  }

  needed_dates <- unique(mapping$snapshot_date)

  if (parquet_tier() == "arrow") {
    ds <- brreg_open(type)
    select_cols <- c("org_nr", "snapshot_date")
    if (!is.null(cols)) {
      select_cols <- unique(c(select_cols, cols))
    }
    result <- ds |>
      dplyr::filter(.data$snapshot_date %in% needed_dates) |>
      dplyr::collect()
    if (!is.null(cols)) {
      keep <- intersect(c("org_nr", "snapshot_date", cols), names(result))
      result <- result[, keep, drop = FALSE]
    }
  } else {
    files <- snaps$path[snaps$snapshot_date %in% needed_dates]
    chunks <- lapply(seq_along(files), function(i) {
      df <- read_parquet_safe(files[i])
      df$snapshot_date <- needed_dates[match(files[i], snaps$path[snaps$snapshot_date %in% needed_dates])]
      if (!is.null(cols)) {
        keep <- intersect(c("org_nr", "snapshot_date", cols), names(df))
        df <- df[, keep, drop = FALSE]
      }
      df
    })
    result <- dplyr::bind_rows(chunks)
  }

  result <- dplyr::inner_join(
    result,
    mapping,
    by = "snapshot_date",
    relationship = "many-to-many"
  )

  result <- add_entry_exit(result)

  if (label) result <- brreg_label(result)

  attr(result, "date_mapping") <- mapping
  attr(result, "frequency") <- frequency
  attr(result, "brreg_panel_meta") <- list(
    index = "snapshot_date", key = "org_nr", frequency = frequency
  )
  result
}


#' Generate year-end target dates
#' @keywords internal
generate_year_targets <- function(from, to) {
  years <- seq(as.integer(format(from, "%Y")),
               as.integer(format(to, "%Y")))
  as.Date(paste0(years, "-12-31"))
}

#' Generate quarter-end target dates
#' @keywords internal
generate_quarter_targets <- function(from, to) {
  from_y <- as.integer(format(from, "%Y"))
  from_q <- ceiling(as.integer(format(from, "%m")) / 3)
  to_y <- as.integer(format(to, "%Y"))
  to_q <- ceiling(as.integer(format(to, "%m")) / 3)

  quarters <- character()
  y <- from_y; q <- from_q
  while (y < to_y || (y == to_y && q <= to_q)) {
    m <- q * 3
    last_day <- seq.Date(as.Date(paste0(y, "-", sprintf("%02d", m), "-01")),
                          length.out = 2, by = "month")[2] - 1
    quarters <- c(quarters, as.character(last_day))
    q <- q + 1
    if (q > 4) { q <- 1; y <- y + 1 }
  }
  as.Date(quarters)
}

#' Generate month-end target dates
#' @keywords internal
generate_month_targets <- function(from, to) {
  starts <- seq.Date(
    as.Date(paste0(format(from, "%Y-%m"), "-01")),
    as.Date(paste0(format(to, "%Y-%m"), "-01")),
    by = "month"
  )
  ends <- vapply(starts, function(s) {
    as.Date(format(seq.Date(s, length.out = 2, by = "month")[2] - 1))
  }, numeric(1))
  as.Date(ends, origin = "1970-01-01")
}

#' Map target dates to nearest prior available snapshots (LOCF)
#' @param available Date vector of available snapshot dates.
#' @param targets Date vector of target dates.
#' @returns A tibble with columns `target_date`, `period`, `snapshot_date`.
#' @keywords internal
resolve_snapshot_dates <- function(available, targets) {
  available <- sort(available)
  result <- tibble::tibble(
    target_date = targets,
    period = as.character(targets),
    snapshot_date = as.Date(NA)
  )
  for (i in seq_along(targets)) {
    candidates <- available[available <= targets[i]]
    if (length(candidates) > 0) {
      result$snapshot_date[i] <- max(candidates)
    }
  }
  result[!is.na(result$snapshot_date), , drop = FALSE]
}


#' Add entry/exit columns to a panel tibble
#' @keywords internal
add_entry_exit <- function(panel) {
  if (!"org_nr" %in% names(panel) || !"period" %in% names(panel)) return(panel)

  entity_periods <- panel |>
    dplyr::group_by(.data$org_nr) |>
    dplyr::mutate(
      is_entry = .data$period == min(.data$period),
      is_exit  = .data$period == max(.data$period)
    ) |>
    dplyr::ungroup()

  if ("bankrupt" %in% names(entity_periods)) {
    entity_periods$is_exit <- entity_periods$is_exit |
      (!is.na(entity_periods$bankrupt) & entity_periods$bankrupt == TRUE)
  }
  entity_periods
}
