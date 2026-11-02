# Retrieve annual accounts (regnskap) from Regnskapsregisteret

Fetch the key figures of the annual accounts filed by a Norwegian legal
entity from the Regnskapsregisteret open API
(`https://data.brreg.no/regnskapsregisteret/regnskap/{orgnr}`, OpenAPI
1.1.16). One row per filing is returned. Since 2026-10-01 the default
response carries up to three fiscal years per account type, consolidated
(`KONSERN`) accounts before company (`SELSKAP`) accounts; requesting an
explicit `year` or `account_type` reveals no further years, and years
the API no longer serves answer 404.

## Usage

``` r
brreg_regnskap(
  org_nr,
  year = NULL,
  account_type = NULL,
  type = c("code", "label")
)
```

## Arguments

- org_nr:

  Character. A single 9-digit organization number, validated with
  [`brreg_validate()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_validate.md).

- year:

  Integer. A single calendar year of the fiscal period's end date
  (`period_end`), including non-calendar fiscal years. `NULL` (default)
  returns every year the API serves.

- account_type:

  Character. `"SELSKAP"` (the company's own accounts) or `"KONSERN"`
  (the group accounts). `NULL` (default) returns both.

- type:

  A type of variables: `"code"` (default) returns the item, group and
  statement codes of
  [regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md)
  and
  [regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
  and the legal form code, `"label"` returns English labels for them
  from
  [regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
  [regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
  and
  [legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md),
  following the eurostat package's pattern as
  [`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
  does. Pipe to
  [`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
  for Norwegian labels or to keep the codes alongside.

## Value

A tibble with one row per filing. Always present when a filing is
returned: `org_nr`, `filing_id` (integer), `journal_nr`, `account_type`,
`period_start` and `period_end` (Date), `currency`, `items` (list of
tibbles with columns `statement`, `group`, `item`, `path`, `level`,
`is_sum`, `value`), `consistent` (logical) and `inconsistencies` (list
of character vectors). Frequently present: `legal_form`,
`parent_company`, `liquidation_accounts`, `presentation_plan`,
`not_audited`, `audit_waived`, `small_enterprise`, `accounting_rules`. A
zero-row tibble typed on the always-present columns when no filing is
available.

## Shape

The result is nested in the tidyr sense: the filing is the observational
unit of the outer table and its line items are the observational unit of
the `items` table nested in each row. Filing attributes (identity,
period, currency, legal form, audit and accounting-principle flags) are
scalar columns renamed through the package's regnskap field map
(`regnskap_dict`, published as `fields` in
`inst/extdata/endpoints.json`). The figures of the three statement
objects the API emits (`eiendeler`, `egenkapitalGjeld`,
`resultatregnskapResultat`) are rows of `items`, one per leaf, with:

- `statement`: `assets`, `equity_liabilities` or `income_statement`.

- `group`: English name of the object the leaf sits in
  (`current_assets`, `equity`, `operating_revenue`, ...), from the group
  map (`groups` in the endpoint spec).

- `item`: English name of the leaf (`total_assets`, `cash_and_bank`,
  `net_income`, ...), from the field map.

- `path`: the API's dot path, unchanged.

- `level`: depth of the leaf in the API's structure.

- `is_sum`: whether the API names the leaf `sum...`, its own marking of
  a total.

- `value`: the amount in full units of `currency`.

The API's grouping is structural, not an additive partition: a group's
total sits beside components and beside sub-group totals (`sumEiendeler`
next to `sumOmloepsmidler` and `sumFordringer`), so adding `value`
across items double counts unless `is_sum` and `group` are used.
`tidyr::unnest(items)` gives the long form and
`tidyr::pivot_wider(names_from = item, values_from = value)` the wide
form. As with
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
only observed fields are emitted and an API field the maps do not know
passes through under an auto-generated snake_case name (an unknown leaf
inside a statement becomes an item, an unknown object outside the
statements becomes scalar columns), so additions BRREG makes to the
filing shape are never dropped. An absent leaf is absent, not zero; an
object the API sends empty ([`{}`](https://rdrr.io/r/base/Paren.html))
contributes no items.

## Consistency flags

Filings are published as filed; the register does not correct them and
neither does this function, but it checks the accounting identities the
structure implies (balance sheet balances, equity and liabilities add up
to their totals, operating and financial results and net income follow
from their components; the list is `identities` in the endpoint spec)
and flags what fails. `consistent` is `TRUE` when every checkable
identity holds within a tolerance of 1 unit of currency, `FALSE` when
any fails and `NA` when none is checkable (an identity is checkable when
its total and every non-optional term are present). `inconsistencies` is
a list-column holding the names of the failing identities, a zero-length
character vector when none fails. In the October 2026 population
(1,129,601 filings) between 0.1% and 2.5% of filings fail each identity
at that tolerance.

Codes are returned by default: `item`, `group` and `statement` are the
codes of
[regnskap_dict](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_dict.md)
and
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
and `legal_form` the register's code. `type = "label"` or
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md)
translates them from
[regnskap_items](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_items.md),
[regnskap_groups](https://sondreskarsten.github.io/tidybrreg/reference/regnskap_groups.md)
and
[legal_forms](https://sondreskarsten.github.io/tidybrreg/reference/legal_forms.md)
in English or Norwegian, inside the nested `items` as well as on the
filing row.

The logical account key is `org_nr`, `account_type` and the year of
`period_end`; `filing_id` identifies the filing itself (a new id under
the same key is a resubmission) and `journal_nr` can be shared by the
`SELSKAP` and `KONSERN` filings of one submission.

## Unsupported accounting plans

Banks, insurers, pension funds and other entities whose accounting plan
(`BANK`, `SKADE`, `LIV`, `PENSJ`, `IDEELL`, ...) the API does not serve
answer HTTP 500 with the message
`oppstillingsplan som ikke er støttet (PLAN)`. That is a property of the
entity, not a transient failure: the typed zero-row tibble is returned
with attributes `http_status = 500L` and `unsupported_plan` (the plan
code), and a `tidybrreg_warning_unsupported_plan` is signalled. Any
other HTTP 500 aborts as documented below.

## Status handling

The per-entity endpoints behind
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md)
and `brreg_regnskap()` share one contract. HTTP 404 means the
organization number is unknown to that endpoint, which for konsern,
signatur, prokura and regnskap is the ordinary case of an entity with
nothing registered there: the typed zero-row tibble is returned with
attribute `http_status = 404L` and no warning. HTTP 410 means the entity
has been deleted: the typed zero-row tibble is returned with
`http_status = 410L`, `deletion_date`, and a
`tidybrreg_warning_deleted`. Any other status of 400 or above aborts
with a `tidybrreg_error_http`. A successful response with nothing
registered returns the typed zero-row tibble with no attribute. Use
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
to distinguish a non-existent organization number from a live entity
with nothing registered.

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
for `last_annual_accounts`, the year of the latest filing the register
knows of,
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md)
for the group whose `KONSERN` accounts consolidate an entity,
[tidybrreg_conditions](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md)
for the conditions signalled.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
acc <- brreg_regnskap("923609016")                   # Equinor ASA, all years
acc[c("account_type", "period_end", "consistent")]
tidyr::unnest(acc, items)                             # one row per line item
brreg_regnskap("923609016", account_type = "SELSKAP", year = 2025)

# English labels for items, groups, statements and the legal form
tidyr::unnest(brreg_regnskap("923609016", type = "label"), items)

# Or pipe to brreg_label() for Norwegian labels
brreg_regnskap("923609016") |> brreg_label(lang = "no")
}
```
