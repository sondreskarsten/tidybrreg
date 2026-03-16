#' Convert tidybrreg output to tsibble
#'
#' Convert the output of [brreg_panel()] or [brreg_series()] to a
#' tsibble for use with the tidyverts ecosystem (fable, feasts,
#' slider). Uses `regular = FALSE` since brreg snapshots are
#' irregularly spaced.
#'
#' @param x A tibble from [brreg_panel()] or [brreg_series()].
#' @param key Character vector of key column(s). For panels, typically
#'   `"org_nr"`. For series, the grouping variable (e.g. `"legal_form"`).
#'   If `NULL`, inferred from the `brreg_panel_meta` attribute.
#' @param index Character. Name of the time index column. Default
#'   `"period"` for series output, `"snapshot_date"` for panel output.
#'
#' @returns A tsibble.
#'
#' @family tidybrreg panel functions
#' @seealso [brreg_panel()], [brreg_series()].
#'
#' @export
#' @examplesIf interactive() && requireNamespace("tsibble", quietly = TRUE)
#' \donttest{
#' panel <- brreg_panel(cols = c("employees", "legal_form"))
#' as_brreg_tsibble(panel)
#' }
as_brreg_tsibble <- function(x, key = NULL, index = NULL) {
  rlang::check_installed("tsibble", reason = "for temporal data structure.")

  meta <- attr(x, "brreg_panel_meta") %||% attr(x, "date_mapping")

  if (is.null(index)) {
    index <- if ("snapshot_date" %in% names(x)) "snapshot_date" else "period"
  }

  if (is.null(key)) {
    if (!is.null(meta) && is.list(meta) && "key" %in% names(meta)) {
      key <- meta$key
    } else if ("org_nr" %in% names(x)) {
      key <- "org_nr"
    }
  }

  if (index == "period" && is.character(x$period)) {
    x$period <- as.Date(paste0(x$period, "-01"))
  }

  if (length(key) == 0 || is.null(key)) {
    tsibble::as_tsibble(x, index = !!rlang::sym(index), regular = FALSE)
  } else {
    key_syms <- rlang::syms(key)
    tsibble::as_tsibble(x, key = !!key_syms, index = !!rlang::sym(index),
                         regular = FALSE)
  }
}
