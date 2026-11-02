# Conditions signalled by tidybrreg

Every error and warning raised by the package carries a class that can
be caught with [`tryCatch()`](https://rdrr.io/r/base/conditions.html) or
silenced with
[`suppressWarnings()`](https://rdrr.io/r/base/warning.html) selectively,
and a set of fields describing the request that produced it. All classes
inherit from `tidybrreg_error` or `tidybrreg_warning`.

## Errors

- `tidybrreg_error_invalid_org_nr`: the organization number failed
  [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md).
  Field `org_nr`.

- `tidybrreg_error_invalid_filter`: a filter is not supported by the
  requested registry (for example `bankrupt` on `underenheter`). Fields
  `registry`, `filter`.

- `tidybrreg_error_not_found`: the endpoint answered HTTP 404 for an
  organization number. Fields `org_nr`, `endpoint`, `status`.

- `tidybrreg_error_http`: any other HTTP status of 400 or above, or a
  failure on the first page of a paginated request. Fields `endpoint`,
  `status`, `messages` (as extracted from the BRREG error body). 429,
  503, 500, 502 and 504 are retried up to three times first (except the
  Regnskapsregisteret 500 for an unsupported accounting plan, which is
  final).

- `tidybrreg_error_rate_limited`: the register answered its rate limit
  as HTTP 200 with the text `Too many requests` on every retry. Fields
  `url`, `status` (200), `attempts`.

- `tidybrreg_error_connection`: the host could not be reached (DNS, TCP,
  TLS or a dropped connection) on every retry. Fields `url`, `attempts`.

- `tidybrreg_error_result_window`: the query matches more entities than
  BRREG's search window can deliver and the request asked for more than
  the window. Fields `endpoint`, `total_matches`, `retrieval_limit`,
  `filters`. See
  [`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md).

## Warnings

- `tidybrreg_warning_deleted`: the entity has been deleted from the
  register (HTTP 410, or HTTP 200 with `respons_klasse`
  `"SlettetEnhet"`). Fields `org_nr`, `deletion_date`.

- `tidybrreg_warning_partial`: a paginated request failed after at least
  one page was retrieved; the partial result is returned with attribute
  `complete = FALSE`. Fields `endpoint`, `status`, `pages_fetched`.

- `tidybrreg_warning_truncated`: more results exist than were returned
  because of `max_results` or `max_pages`; the result carries attribute
  `complete = FALSE`. Fields `endpoint`, `returned`, `total_matches`.

- `tidybrreg_warning_unknown_member`: an update feed carried a member
  the package does not model; it is passed through unchanged. Field
  `members`.

- `tidybrreg_warning_bundled_fallback`: SSB KLASS was unreachable and a
  bundled dictionary was used instead. Fields `dictname`, `vintage`.

- `tidybrreg_warning_unresolved`: the Fullmakt service answered HTTP 200
  but declined to resolve the signature or procuration rule mechanically
  (`status.rutineStatus`); the typed empty result carries
  `http_status = 200L`, `routine_status` and `routine_text`. Fields
  `org_nr`, `signature_type`, `routine_status`, `routine_text`. See
  [`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md).

- `tidybrreg_warning_unsupported_plan`: Regnskapsregisteret does not
  serve the entity's accounting plan (banks, insurers, pension funds);
  the typed empty result carries `http_status = 500L` and
  `unsupported_plan`. Fields `org_nr`, `plan`, `api_message`. See
  [`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md).

- `tidybrreg_warning_parse`: values could not be coerced to the type
  declared in
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md);
  the result carries attribute `brreg_parse_problems`. Field `n`.

## See also

Other tidybrreg utilities:
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
[`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md),
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md),
[`tidybrreg_endpoints`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_endpoints.md)

## Examples

``` r
tryCatch(
  brreg_entity("123456789"),
  tidybrreg_error_invalid_org_nr = function(e) e$org_nr
)
#> [1] "123456789"
```
