# Offline HTTP mocking for the tidybrreg endpoint wrappers.
#
# `local_brreg_responses()` replaces the package's single request runner,
# brreg_perform(), with a queue of canned responses and swaps the httr2
# accessors so the wrappers read status, body and headers from the canned
# objects. Nothing touches the network.

stub_resp <- function(status = 200L, body = list(), headers = list()) {
  structure(list(status = as.integer(status), body = body, headers = headers),
            class = "tidybrreg_stub_resp")
}

local_brreg_responses <- function(responses, env = parent.frame()) {
  if (!is.null(names(responses)) || inherits(responses, "tidybrreg_stub_resp")) {
    responses <- list(responses)
  }
  queue <- new.env()
  queue$items <- responses
  queue$requests <- list()
  testthat::local_mocked_bindings(
    brreg_perform = function(req) {
      queue$requests[[length(queue$requests) + 1L]] <- req
      if (length(queue$items) == 0) stop("mock queue exhausted")
      r <- queue$items[[1L]]
      queue$items <- queue$items[-1L]
      r
    },
    .package = "tidybrreg", .env = env
  )
  testthat::local_mocked_bindings(
    resp_status = function(resp) {
      if (inherits(resp, "tidybrreg_stub_resp")) resp$status else stop("not a stub")
    },
    resp_body_json = function(resp, ...) resp$body,
    resp_header = function(resp, header, default = NULL) {
      resp$headers[[header]] %||% default
    },
    .package = "httr2", .env = env
  )
  queue
}

entity_body <- function(org_nr = "923609016", ...) {
  c(list(
    organisasjonsnummer = org_nr,
    navn = "EQUINOR ASA",
    organisasjonsform = list(kode = "ASA", beskrivelse = "Allmennaksjeselskap",
                             `_links` = list(self = list(href = "https://x/ASA"))),
    stiftelsesdato = "1972-09-18",
    antallAnsatte = 21408L,
    naeringskode1 = list(kode = "06.100", beskrivelse = "Utvinning"),
    konkurs = FALSE,
    `_links` = list(self = list(href = "https://x/923609016"))
  ), list(...))
}

search_body <- function(items, total = length(items), has_next = FALSE) {
  list(
    `_embedded` = list(enheter = items),
    page = list(size = 100L, totalElements = total, totalPages = 1L, number = 0L),
    `_links` = if (has_next) list(`next` = list(href = "https://x?page=1")) else list()
  )
}

update_body <- function(updates, type = "enheter") {
  key <- paste0("oppdaterte", tools::toTitleCase(type))
  body <- list(`_embedded` = list())
  body[["_embedded"]][[key]] <- updates
  body
}

update_event <- function(id, org_nr = "923609016", type = "Endring",
                         dato = "2026-03-15T10:30:00.000Z", endringer = NULL, ...) {
  c(list(oppdateringsid = id, organisasjonsnummer = org_nr,
         endringstype = type, dato = dato, endringer = endringer), list(...))
}
