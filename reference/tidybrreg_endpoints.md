# Retrieval limits of the register endpoints

One row per endpoint reachable through the fifteen exports, with the
pagination model, the retrieval window, and how the package behaves at
the boundary. The evidence column separates what BRREG documents
(<https://data.brreg.no/enhetsregisteret/api/dokumentasjon/>) from what
has been observed against the live service; limits observed for one
route are never assumed for another. Boundary probes for the search
routes run in the scheduled live test workflow
(`tests/testthat/test-liveapi-audit.R`).

## Enhetsregisteret API

Base URL `https://data.brreg.no/enhetsregisteret/api`.

|  |  |  |  |  |
|----|----|----|----|----|
| Route | Function | Pagination | Limits and boundary | Evidence |
| `GET /enheter/{orgnr}` | [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md) | none | 200 (entity or `SlettetEnhet`), 404 unknown, 410 deleted | documented; 200-with-`SlettetEnhet` observed on 25/25 recent deletions (2026-08) |
| `GET /underenheter/{orgnr}` | [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md) | none | as enheter | documented |
| `GET /enheter?...` | [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md), [`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md) | `page`/`size`; `page.totalElements` reported | `size` at most 10,000; `size * (page + 1)` at most 10,000, else HTTP 400; the package aborts with `tidybrreg_error_result_window` when `total_matches` exceeds the window and more was requested; an employee range within 1 to 4 (`fraAntallAnsatte`/`tilAntallAnsatte`) is refused for privacy with HTTP 400 | observed 2026-08-08 (Bergen query: 57,954 matches; result 10,000 retrievable, 10,001 answered 400); privacy rule observed 2026-10-30 |
| `GET /underenheter?...` | [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md), [`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md) | as enheter | as enheter; no `konkurs` filter (the package rejects `bankrupt`) | documented; window probed in the live suite |
| `GET /enheter/{orgnr}/roller` | [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md) | none (whole payload) | 404 unknown entity, 410 deleted; empty `rollegrupper` for an entity without roles | documented |
| `GET /roller/enheter/{orgnr}/juridiskeroller` | [`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md) | none | 404 when nothing is registered | documented |
| `GET /konsernstruktur/{orgnr}` | [`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md) | none (recursive tree) | 404 both for unknown numbers and for entities in no group; depth observed to 6 | documented; depth observed (ASA census, 2026-10) |
| `GET /oppdateringer/enheter`, `/oppdateringer/underenheter` | [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md), [`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md) | cursor: `dato` for the first page, `oppdateringsid` (exclusive) thereafter; `size` at most 10,000 | no documented window; field patches (`includeChanges`) available from 2025-09 | documented; cursor semantics observed |
| `GET /oppdateringer/roller` | [`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md) with `type = "roller"` | `afterTime` for the first page, `afterId` thereafter; `size` at most 10,000 | CloudEvents without field detail | documented; `afterId` pagination not yet probed live |
| `GET /enheter/lastned`, `/underenheter/lastned`, `/roller/totalbestand` | [`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md) | none (one gzipped JSON file) | regenerated nightly; `ETag` and `Last-Modified` sent; the CSV variants (`/lastned/csv`) are not read | documented; sizes observed 2026-08 (196 / 75 / 131 MB) |
| `GET /organisasjonsformer` | build script only | none | 44 codes | observed 2026-06-16 |

## Fullmakt service

Base URL `https://data.brreg.no/fullmakt`.

|  |  |  |  |  |
|----|----|----|----|----|
| Route | Function | Pagination | Limits and boundary | Evidence |
| `GET /enheter/{orgnr}/signatur` | [`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md) | none | 404 when nothing is registered (common for ENK); 200 with `status.rutineStatus` and no combinations when the rule cannot be resolved mechanically (`tidybrreg_warning_unresolved`) | documented; unresolved case observed 2026-10-30 (Equinor ASA) |
| `GET /enheter/{orgnr}/prokura` | [`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md) | none | as signatur | documented |

## Regnskapsregisteret API

Base URL `https://data.brreg.no/regnskapsregisteret/regnskap` (OpenAPI
1.1.16).

|  |  |  |  |  |
|----|----|----|----|----|
| Route | Function | Pagination | Limits and boundary | Evidence |
| `GET /{orgnr}`, optional `år`, `regnskapstype` | [`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md) | none (whole array) | up to three fiscal years per type since 2026-10-01, KONSERN before SELSKAP; 404 when no accounts are served (unknown number, no filing, or a year outside the window); HTTP 500 `oppstillingsplan som ikke er støttet (PLAN)` for banks, insurers and pension funds, mapped to `tidybrreg_warning_unsupported_plan` | documented; behaviour change observed 2026-10-06 (six filings per ASA) |

## SSB KLASS (not BRREG)

Base URL `https://data.ssb.no/api/klass/v1`.

|  |  |  |  |  |
|----|----|----|----|----|
| Route | Function | Pagination | Limits and boundary | Evidence |
| `GET /classifications/6/codesAt`, `/classifications/39/codesAt` | [`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md) | none | whole code list for a date and language | observed 2026-06-16 |

## Rate limiting

BRREG publishes no rate limit or rate-limit headers; the package
throttles itself to 5 requests per second per host and retries 429, 503,
500, 502 and 504 up to three times, as well as connection failures and
the register's rate limit when it arrives as HTTP 200 with the text
`Too many requests` (then a `tidybrreg_error_rate_limited`). The
Regnskapsregisteret 500 for an unsupported accounting plan is final.
Request timeouts are httr2's defaults.

## See also

Other tidybrreg utilities:
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md),
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md),
[`tidybrreg_conditions`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
