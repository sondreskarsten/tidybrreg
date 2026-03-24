#' Compute field-level diffs between two roller state tibbles
#'
#' Pure function: takes two flattened roller tibbles (as produced by
#' [flatten_roles()] or [parse_roles_bulk()]) and returns a long-format
#' changelog recording every field-level mutation. Detects three
#' categories of change: role additions, role removals, and
#' field-level modifications on continuing roles.
#'
#' @section Composite key:
#' Each role assignment is identified by
#' `(org_nr, role_group_code, role_code, holder_id)` where `holder_id`
#' is derived from `person_id` for person-held roles and
#' `entity:{entity_org_nr}` for entity-held roles (auditors,
#' accountants). Roles with neither are keyed as `unknown:{row_index}`
#' within their respective state — these are rare and produce
#' conservative add/remove pairs rather than false modifications.
#'
#' @section NA handling:
#' For additions, fields that are `NA` in the new state are excluded
#' from the changelog (no value to report). For removals, fields that
#' are `NA` in the old state are excluded. For modifications, a change
#' from `NA` to a non-NA value (or vice versa) is recorded.
#'
#' @param old_state Tibble. Previous roller state from
#'   [read_state()] or an earlier [flatten_roles()] call.
#'   `NULL` or zero-row tibble treats all current roles as additions.
#' @param new_state Tibble. Current roller state from
#'   [brreg_download()] or [flatten_roles()].
#' @param timestamp Character or POSIXct. Timestamp for changelog
#'   entries (typically the CDC event time or sync time).
#' @param update_id Integer or character. Identifier for the sync
#'   batch, used as `update_id` in the changelog.
#'
#' @returns A tibble matching the changelog schema: `timestamp`,
#'   `org_nr`, `registry` (always `"roller"`), `change_type`
#'   (`"entry"`, `"exit"`, `"change"`), `field`, `value_from`,
#'   `value_to`, `update_id`.
#'
#' @family tidybrreg data management functions
#' @keywords internal
diff_roller_state <- function(old_state, new_state,
                               timestamp = format(Sys.time(),
                                                   "%Y-%m-%dT%H:%M:%S"),
                               update_id = NA_integer_) {

  value_cols <- c(
    "role_group", "role", "first_name", "middle_name", "last_name",
    "deceased", "entity_org_nr", "entity_name",
    "resigned", "deregistered", "ordering", "elected_by",
    "group_modified"
  )

  new_keyed <- add_role_key(new_state)
  new_keyed <- dplyr::distinct(new_keyed, .data$role_key, .keep_all = TRUE)

  if (is.null(old_state) || nrow(old_state) == 0) {
    return(roles_to_changelog(new_keyed, "entry", value_cols,
                               timestamp, update_id))
  }

  old_state <- backfill_roller_cols(old_state)
  old_keyed <- add_role_key(old_state)
  old_keyed <- dplyr::distinct(old_keyed, .data$role_key, .keep_all = TRUE)

  added_keys   <- setdiff(new_keyed$role_key, old_keyed$role_key)
  removed_keys <- setdiff(old_keyed$role_key, new_keyed$role_key)
  common_keys  <- intersect(new_keyed$role_key, old_keyed$role_key)

  added <- if (length(added_keys) > 0) {
    roles_to_changelog(
      new_keyed[new_keyed$role_key %in% added_keys, ],
      "entry", value_cols, timestamp, update_id
    )
  }

  removed <- if (length(removed_keys) > 0) {
    roles_to_changelog(
      old_keyed[old_keyed$role_key %in% removed_keys, ],
      "exit", value_cols, timestamp, update_id
    )
  }

  modified <- if (length(common_keys) > 0) {
    diff_common_roles(
      old_keyed[old_keyed$role_key %in% common_keys, ],
      new_keyed[new_keyed$role_key %in% common_keys, ],
      value_cols, timestamp, update_id
    )
  }

  dplyr::bind_rows(added, removed, modified)
}


#' Derive holder_id and composite role_key
#'
#' Adds `holder_id` and `role_key` columns. Person-held roles use
#' `person_id`; entity-held roles use `entity:{org_nr}`; roles
#' with neither get a positional fallback.
#'
#' @param df Tibble from [flatten_roles()].
#' @returns The input with `holder_id` and `role_key` appended.
#' @keywords internal
add_role_key <- function(df) {
  df$holder_id <- dplyr::case_when(
    !is.na(df$person_id)     ~ df$person_id,
    !is.na(df$entity_org_nr) ~ paste0("entity:", df$entity_org_nr),
    TRUE                     ~ paste0("unknown:", seq_len(nrow(df)))
  )
  df$role_key <- paste(df$org_nr, df$role_group_code, df$role_code,
                        df$holder_id, sep = "|")
  df
}


#' Convert role rows to long-format changelog entries
#'
#' For entries (`change_type = "entry"`), each non-NA value field
#' becomes a row with `value_from = NA, value_to = value`. For exits,
#' the reverse.
#'
#' @param df Keyed role tibble (with `role_key`, `holder_id`).
#' @param change_type One of `"entry"` or `"exit"`.
#' @param value_cols Character vector of field names to pivot.
#' @param timestamp,update_id Passed through to output.
#' @returns A tibble in changelog schema.
#' @keywords internal
roles_to_changelog <- function(df, change_type, value_cols,
                                timestamp, update_id) {
  present_cols <- intersect(value_cols, names(df))
  if (length(present_cols) == 0 || nrow(df) == 0) {
    return(empty_changelog())
  }

  value_name <- if (change_type == "entry") "value_to" else "value_from"
  other_name <- if (change_type == "entry") "value_from" else "value_to"

  long <- df |>
    dplyr::select(
      dplyr::all_of(c("org_nr", "role_key", present_cols))
    ) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(present_cols), as.character)) |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(present_cols),
      names_to = "field",
      values_to = value_name
    ) |>
    dplyr::filter(!is.na(.data[[value_name]]))

  if (nrow(long) == 0) return(empty_changelog())

  long[[other_name]] <- NA_character_
  long$timestamp   <- as.character(timestamp)
  long$registry    <- "roller"
  long$change_type <- change_type
  long$update_id   <- as.integer(update_id)

  long |>
    dplyr::select(
      "timestamp", "org_nr", "registry", "change_type",
      "field", "value_from", "value_to", "update_id"
    )
}


#' Diff fields on roles that exist in both old and new state
#'
#' Joins on `role_key`, casts all value columns to character, and
#' detects field-level changes including NA transitions.
#'
#' @param old_df,new_df Keyed role tibbles filtered to common keys.
#' @param value_cols Fields to compare.
#' @param timestamp,update_id Passed through.
#' @returns Tibble in changelog schema (only rows where values differ).
#' @keywords internal
diff_common_roles <- function(old_df, new_df, value_cols,
                               timestamp, update_id) {
  present_cols <- intersect(value_cols, intersect(names(old_df), names(new_df)))
  if (length(present_cols) == 0) return(empty_changelog())

  join_cols <- c("role_key", "org_nr")

  old_long <- old_df |>
    dplyr::select(dplyr::all_of(c(join_cols, present_cols))) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(present_cols), as.character)) |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(present_cols),
      names_to = "field", values_to = "value_from"
    )

  new_long <- new_df |>
    dplyr::select(dplyr::all_of(c(join_cols, present_cols))) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(present_cols), as.character)) |>
    tidyr::pivot_longer(
      cols = dplyr::all_of(present_cols),
      names_to = "field", values_to = "value_to"
    )

  diffs <- dplyr::inner_join(old_long, new_long,
                              by = c(join_cols, "field")) |>
    dplyr::filter(
      !is.na(.data$value_from) | !is.na(.data$value_to),
      !identical_or_both_na(.data$value_from, .data$value_to)
    )

  if (nrow(diffs) == 0) return(empty_changelog())

  diffs |>
    dplyr::mutate(
      timestamp   = as.character(timestamp),
      registry    = "roller",
      change_type = "change",
      update_id   = as.integer(update_id)
    ) |>
    dplyr::select(
      "timestamp", "org_nr", "registry", "change_type",
      "field", "value_from", "value_to", "update_id"
    )
}


#' Vectorised NA-safe equality check
#'
#' Returns `TRUE` where both values are `NA` or both are equal.
#' Used in diff filtering to exclude unchanged fields.
#'
#' @param x,y Character vectors of equal length.
#' @returns Logical vector.
#' @keywords internal
identical_or_both_na <- function(x, y) {
  both_na <- is.na(x) & is.na(y)
  same    <- !is.na(x) & !is.na(y) & x == y
  both_na | same
}


#' Backfill missing columns on legacy roller state
#'
#' State files written before v0.3.4 lack `deregistered`, `ordering`,
#' `elected_by`, and `group_modified`. This function adds them as
#' `NA` with correct types so that [diff_roller_state()] can compare
#' old and new states without column mismatch errors.
#'
#' @param df Roller state tibble (possibly missing columns).
#' @returns The input with any missing columns added.
#' @keywords internal
backfill_roller_cols <- function(df) {
  if (!"deregistered" %in% names(df))  df$deregistered  <- NA
  if (!"ordering" %in% names(df))      df$ordering      <- NA_integer_
  if (!"elected_by" %in% names(df))    df$elected_by    <- NA_character_
  if (!"group_modified" %in% names(df)) df$group_modified <- as.Date(NA)
  df
}
