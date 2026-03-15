# tidybrreg <img src="man/figures/logo.png" align="right" height="139" alt="" />

<!-- badges: start -->
[![R-CMD-check](https://github.com/sondreskarsten/tidybrreg/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/sondreskarsten/tidybrreg/actions/workflows/R-CMD-check.yaml)
<!-- badges: end -->

Tidy R interface to Norway's [Central Coordinating Register for Legal Entities](https://www.brreg.no/en/) (Enhetsregisteret), maintained by the Brønnøysund Register Centre.

Every legal entity operating in Norway — companies, partnerships, sole proprietorships, associations, foundations, and government bodies — is assigned a unique 9-digit organization number and registered in this central register. The register contains approximately 1 million active entities. Data is freely available under the [Norwegian Licence for Open Government Data (NLOD 2.0)](https://data.norge.no/nlod/en/2.0).

## Installation

``` r
# Install from GitHub
# install.packages("pak")
pak::pak("sondreskarsten/tidybrreg")
```

## Usage

``` r
library(tidybrreg)

# Look up a single entity
brreg_entity("923609016")
#> # A tibble: 1 × 61
#>   org_nr    name        legal_form founding_date employees nace_1 municipality
#>   <chr>     <chr>       <chr>      <date>            <int> <chr>  <chr>
#> 1 923609016 EQUINOR ASA ASA        1972-09-18        21408 06.100 STAVANGER

# Translate codes to English
brreg_entity("923609016") |> brreg_label()
#> legal_form: "Public limited company"
#> nace_1:     "Extraction of crude petroleum"

# Search
brreg_search(legal_form = "AS", municipality_code = "0301",
             min_employees = 500, max_results = 10)

# Board members and officers
brreg_roles("923609016")
#> # A tibble: 16 × 14
#>   org_nr    role_group         role                first_name last_name
#>   <chr>     <chr>              <chr>               <chr>      <chr>
#> 1 923609016 Management         CEO / Managing Dir… Anders     Opedal
#> 2 923609016 Board of Directors Chair of the Board  Jon Erik   Reinhardsen
#> 3 923609016 Board of Directors Board Member        Anne       Drinkwater
#> …

# Validate organization numbers
brreg_validate(c("923609016", "123456789"))
#> [1]  TRUE FALSE
```

## Design

tidybrreg follows a **codes by default, labels on demand** architecture:

- **Column names** are translated from Norwegian to English via a data-driven dictionary (`field_dict`). API fields not in the dictionary pass through with auto-generated snake_case names — new fields added by brreg are never silently dropped.

- **Coded values** (legal forms, NACE industry codes, roles) are returned as codes by default. Call `brreg_label()` to translate to English descriptions. NACE labels can be refreshed from the [SSB Klass API](https://data.ssb.no/api/klass/v1/) at runtime via `brreg_label(refresh = TRUE)`.

- **Reference data** is bundled from live API sources and regenerated via `data-raw/build_dictionaries.R`: 44 legal forms, 18 role types, 1783 NACE codes (English), 33 institutional sector codes.

## Available functions

| Function | Description |
|---|---|
| `brreg_entity()` | Look up a single entity by organization number |
| `brreg_search()` | Search entities by name, legal form, industry, geography |
| `brreg_roles()` | Board members, officers, and auditors |
| `brreg_board_summary()` | Derived board-level covariates |
| `brreg_updates()` | Incremental change stream (CDC) |
| `brreg_label()` | Translate codes to English descriptions |
| `brreg_validate()` | Validate organization numbers (modulus-11) |

## Reference datasets

| Dataset | Description |
|---|---|
| `field_dict` | Column name mapping (49 Norwegian → English mappings) |
| `legal_forms` | 44 legal form codes with English translations |
| `role_types` | 18 role codes with English translations |
| `role_groups` | 15 role group codes with English translations |

## Norwegian legal forms

Common codes for the `legal_form` parameter in `brreg_search()`:

| Code | English | Norwegian |
|---|---|---|
| AS | Private limited company | Aksjeselskap |
| ASA | Public limited company | Allmennaksjeselskap |
| ENK | Sole proprietorship | Enkeltpersonforetak |
| NUF | Norwegian-registered foreign entity | Norskregistrert utenlandsk foretak |
| ANS | General partnership (joint liability) | Ansvarlig selskap |
| STI | Foundation | Stiftelse |
| SA | Cooperative | Samvirkeforetak |

See `legal_forms` for the complete list.

## License

MIT. Data from Enhetsregisteret is available under [NLOD 2.0](https://data.norge.no/nlod/en/2.0).
