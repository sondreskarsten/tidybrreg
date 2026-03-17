# Getting started with tidybrreg

tidybrreg provides tidy access to Norway’s Central Coordinating Register
for Legal Entities (Enhetsregisteret), maintained by the Brønnøysund
Register Centre at [data.brreg.no](https://data.brreg.no). The register
contains approximately 1 million active entities — companies,
partnerships, sole proprietorships, associations, and government bodies.

## Installation

``` r
# install.packages("pak")
pak::pak("sondreskarsten/tidybrreg")
```

For snapshot and panel features, also install a parquet backend:

``` r
install.packages("nanoparquet")  # lightweight, read/write only
# OR
install.packages("arrow")       # full-featured, lazy queries
```

## Look up a single entity

Every Norwegian legal entity has a unique 9-digit organization number
(organisasjonsnummer). Look up Equinor ASA:

``` r
library(tidybrreg)

brreg_entity("923609016")
#> # A tibble: 1 × 65
#>   org_nr    name        legal_form founding_date employees nace_1
#>   <chr>     <chr>       <chr>      <date>            <int> <chr>
#> 1 923609016 EQUINOR ASA ASA        1972-09-18        21408 06.100
```

The result is a tibble with English column names mapped from the
Norwegian API via the package’s `field_dict`. All 49 dictionary-mapped
columns are present in every output, filled with typed `NA` when the API
omits a field.

## Translate codes to labels

By default, functions return raw codes (`ASA`, `06.100`). Two ways to
get English labels:

``` r
# Option 1: inline via type = "label"
brreg_entity("923609016", type = "label")

# Option 2: pipe to brreg_label() for more control
brreg_entity("923609016") |>
  brreg_label(code = c("legal_form", "nace_1"))
#> legal_form      = "Public limited company"
#> legal_form_code = "ASA"  (original code preserved)
#> nace_1          = "Extraction of crude petroleum"
#> nace_1_code     = "06.100"
```

The `code =` argument keeps the original code in a `_code` suffixed
column alongside the label — following the eurostat package’s pattern.

## Search for entities

Query by name, legal form, geography, industry, employee count, or any
combination:

``` r
# Large private companies in Oslo
brreg_search(
  legal_form = "AS",
  municipality_code = "0301",
  min_employees = 500,
  max_results = 10
)
```

Search results are paginated automatically up to `max_results` or the
API’s 10,000-result ceiling. For larger extractions, use
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md).

### Sub-entities (establishments)

Use `registry = "underenheter"` to search sub-entities — branch offices,
plants, and establishments linked to a parent entity:

``` r
brreg_search(name = "Equinor", registry = "underenheter", max_results = 5)
```

## Retrieve roles

Board members, officers, and auditors for any entity:

``` r
roles <- brreg_roles("923609016")
roles
#> # A tibble: 25 × 14
#>   org_nr    role_group        role              first_name last_name birth_date
#>   <chr>     <chr>             <chr>             <chr>      <chr>     <date>
#> 1 923609016 Board of Directors Chair of the Board Jon Erik   Reinhardsen 1960-07-14
#> 2 923609016 Board of Directors Board member      ...
```

Derive board-level summary covariates:

``` r
brreg_board_summary(roles)
#> # A tibble: 1 × 10
#>   org_nr    board_size n_chair n_members has_ceo has_auditor auditor_org_nr
```

## Bulk download the full register

Three registries available:

``` r
# Main entities: ~152 MB CSV or ~196 MB JSON
entities <- brreg_download(type = "enheter")

# JSON captures additional fields not in CSV
entities_json <- brreg_download(type = "enheter", format = "json")

# Sub-entities: ~59 MB
sub_entities <- brreg_download(type = "underenheter")

# All roles for all entities: ~131 MB JSON
all_roles <- brreg_download(type = "roller")
```

Downloads are cached in `tools::R_user_dir("tidybrreg", "cache")`. Use
`refresh = TRUE` to force re-download, or `refresh = "auto"` to
re-download only when the server has a newer version (ETag-based).

## Function → API endpoint mapping

| Function                                          | API endpoint                              | Returns              |
|---------------------------------------------------|-------------------------------------------|----------------------|
| `brreg_entity(org_nr)`                            | `/enheter/{orgnr}`                        | 1-row tibble         |
| `brreg_entity(org_nr, registry = "underenheter")` | `/underenheter/{orgnr}`                   | 1-row tibble         |
| `brreg_search(...)`                               | `/enheter?...`                            | N-row tibble         |
| `brreg_search(..., registry = "underenheter")`    | `/underenheter?...`                       | N-row tibble         |
| `brreg_roles(org_nr)`                             | `/enheter/{orgnr}/roller`                 | N-row tibble         |
| `brreg_roles_legal(org_nr)`                       | `/roller/enheter/{orgnr}/juridiskeroller` | N-row tibble         |
| `brreg_download("enheter")`                       | `/enheter/lastned/csv`                    | Full register tibble |
| `brreg_download("enheter", format = "json")`      | `/enheter/lastned`                        | Full register tibble |
| `brreg_download("roller")`                        | `/roller/totalbestand`                    | Full roles tibble    |
| `brreg_updates(type = "enheter")`                 | `/oppdateringer/enheter`                  | Change events tibble |
| `brreg_updates(type = "roller")`                  | `/oppdateringer/roller`                   | Change events tibble |

## Next steps

- [`vignette("business-data")`](https://sondreskarsten.github.io/tidybrreg/articles/business-data.md)
  — Norwegian legal forms, NACE codes, and data quirks
- [`vignette("panels")`](https://sondreskarsten.github.io/tidybrreg/articles/panels.md)
  — Building firm-period panels and time series from snapshots
- [`vignette("governance")`](https://sondreskarsten.github.io/tidybrreg/articles/governance.md)
  — Board networks and survival analysis
