#' Validate Norwegian organization numbers
#'
#' Check whether organization numbers (organisasjonsnummer) pass the
#' modulus-11 check digit algorithm used by Norway's Central Coordinating
#' Register for Legal Entities. Valid numbers are exactly 9 digits, start
#' with 8 or 9, and have a correct check digit computed with weights
#' `3, 2, 7, 6, 5, 4, 3, 2`.
#'
#' @param org_nr Character vector of organization numbers to validate.
#'
#' @returns Logical vector the same length as `org_nr`. `TRUE` for valid
#'   numbers, `FALSE` otherwise.
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
    if (!grepl("^[89]\\d{8}$", x)) return(FALSE)
    d <- as.integer(strsplit(x, "")[[1]])
    w <- c(3L, 2L, 7L, 6L, 5L, 4L, 3L, 2L)
    r <- sum(d[1:8] * w) %% 11L
    check <- if (r == 0L) 0L else 11L - r
    check < 10L && check == d[9]
  }, logical(1), USE.NAMES = FALSE)
}
