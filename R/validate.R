#' Validate Norwegian organization numbers
#'
#' Check whether organization numbers (organisasjonsnummer) pass the
#' modulus-11 check digit algorithm used by Norway's Central Coordinating
#' Register for Legal Entities. Valid numbers are exactly 9 digits, start
#' with 8 or 9 (the series the register allocates from), and have a
#' correct check digit computed with weights `3, 2, 7, 6, 5, 4, 3, 2`.
#'
#' @param org_nr Character vector of organization numbers to validate.
#'
#' @returns Logical vector the same length as `org_nr`. `TRUE` for valid
#'   numbers, `FALSE` otherwise (including `NA` input).
#'
#' @family tidybrreg utilities
#' @seealso [brreg_entity()] which validates before querying the API.
#'
#' @export
#' @examples
#' brreg_validate(c("923609016", "984851006", "123456789", "999999999"))
brreg_validate <- function(org_nr) {
  org_nr <- as.character(org_nr)
  vapply(org_nr, function(x) {
    if (is.na(x) || !grepl("^[89]\\d{8}$", x)) return(FALSE)
    d <- as.integer(strsplit(x, "")[[1]])
    w <- c(3L, 2L, 7L, 6L, 5L, 4L, 3L, 2L)
    r <- sum(d[1:8] * w) %% 11L
    check <- if (r == 0L) 0L else 11L - r
    check < 10L && check == d[9]
  }, logical(1), USE.NAMES = FALSE)
}

#' Validate a single organization number argument or abort
#' @param org_nr The value supplied by the caller.
#' @param arg Argument name for the error message.
#' @keywords internal
check_org_nr <- function(org_nr, arg = "org_nr", call = rlang::caller_env()) {
  org_nr <- as.character(org_nr)
  if (length(org_nr) != 1L) {
    brreg_abort(c(
      "{.arg {arg}} must be a single organization number, not {length(org_nr)}.",
      "i" = "Iterate with {.code lapply(org_nrs, brreg_entity)} for several entities."
    ), class = "invalid_org_nr", org_nr = org_nr, call = call)
  }
  if (!brreg_validate(org_nr)) {
    brreg_abort(c(
      "Invalid organization number: {.val {org_nr}}",
      "i" = "Must be 9 digits starting with 8 or 9, with a modulus-11 check digit.",
      "i" = "Examples: 923609016 (Equinor), 984851006 (DNB Bank)"
    ), class = "invalid_org_nr", org_nr = org_nr, call = call)
  }
  org_nr
}
