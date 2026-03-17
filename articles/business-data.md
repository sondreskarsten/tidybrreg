# Norwegian business entity data

This vignette documents the structure and quirks of data from Norway’s
Central Coordinating Register for Legal Entities (Enhetsregisteret).
Understanding these details prevents misinterpretation in research.

## Organization numbers

Every Norwegian legal entity receives a unique 9-digit organization
number (organisasjonsnummer) upon registration. The number uses
modulus-11 check digit validation:

``` r
library(tidybrreg)
#> tidybrreg: bulk data not yet downloaded for: enheter, underenheter, roller.
#> Run brreg_snapshot() for full network/panel support. See ?brreg_status for details.
brreg_validate(c("923609016", "984851006", "123456789"))
#> [1]  TRUE  TRUE FALSE
```

Numbers starting with 8 are assigned to sub-entities (underenheter),
numbers starting with 9 to main entities (enheter). Historical numbers
starting with other digits exist but are no longer assigned.

## Three registries, one API

The brreg API exposes three distinct registries:

**Enheter** (main entities): The legal entity itself — the company,
association, or government body that holds rights, obligations, and is
the unit of taxation.

**Underenheter** (sub-entities): Physical locations or operational units
belonging to a main entity. A company with offices in Oslo and Bergen
has one enhet and two underenheter. Sub-entities have their own
organization numbers and are linked to their parent via
`overordnetEnhet`.

**Roller** (roles): Board members, officers, auditors, accountants, and
shareholders registered for each entity. Roles link persons (by name +
birth date) or entities (by organization number) to entities.

## Legal forms

The `organisasjonsform` field classifies entities. Common codes:

``` r
legal_forms[legal_forms$code %in% c("AS", "ASA", "ENK", "NUF", "DA", "ANS", "SA", "STI"), ]
#> # A tibble: 8 × 4
#>   code  name_no                                 expired name_en                 
#>   <chr> <chr>                                   <chr>   <chr>                   
#> 1 ANS   Ansvarlig selskap med solidarisk ansvar NA      General partnership (jo…
#> 2 AS    Aksjeselskap                            NA      Private limited company 
#> 3 ASA   Allmennaksjeselskap                     NA      Public limited company  
#> 4 DA    Ansvarlig selskap med delt ansvar       NA      General partnership (sh…
#> 5 ENK   Enkeltpersonforetak                     NA      Sole proprietorship     
#> 6 NUF   Norskregistrert utenlandsk foretak      NA      Norwegian-registered fo…
#> 7 SA    Samvirkeforetak                         NA      Cooperative             
#> 8 STI   Stiftelse                               NA      Foundation
```

Key distinctions for research:

- **AS** (Private limited company): ~300K entities. Minimum NOK 30,000
  share capital. Board optional for small AS.
- **ASA** (Public limited company): ~220 entities. Listed or intending
  to list. Gender quota on boards (≥40% each gender since 2008).
- **ENK** (Sole proprietorship): ~400K entities. No board, no separate
  legal personality. Often zero employees.
- **NUF** (Norwegian-registered foreign entity): Branch offices of
  foreign companies. Limited data available.

## NACE industry codes

The `naeringskode1` field uses the Standard Industrial Classification
(SN2007, based on NACE Rev. 2). The brreg API switched to SN2025 (NACE
Rev. 2.1) in September 2025. Use
[`brreg_harmonize_nace()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_nace.md)
to map between the two.

``` r
# Translate NACE codes to English descriptions
brreg_entity("923609016") |> brreg_label(code = "nace_1")
#> nace_1 = "Extraction of crude petroleum"
#> nace_1_code = "06.100"

# Or fetch the full dictionary
nace <- get_brreg_dic("nace")
nace[nace$code == "06.100", ]
```

Up to three NACE codes may be registered per entity (`nace_1`, `nace_2`,
`nace_3`). The primary code (`nace_1`) determines industry
classification.

## Employee counts

The `antallAnsatte` field reports registered employees. Important
caveats:

- Source: NAV’s Aa-register (employer/employee register), updated ~10th
  of each month.
- Since September 2023, entities with 0–4 employees show `NA`
  (previously showed exact count). This means `NA` is ambiguous: the
  entity may have 0–4 employees or the field may genuinely be missing.
- `harRegistrertAntallAnsatte` (logical) distinguishes “has a count
  registered” from “no count registered.”
- ENK (sole proprietorships) typically show `NA` regardless of actual
  employment.

## Addresses

Each entity may have two addresses:

- **forretningsadresse** (business address): Legal registered address.
  Norwegian entities must have a Norwegian business address.
- **postadresse** (postal address): Mailing address. May be a PO box or
  abroad.

Sub-entities use **beliggenhetsadresse** (location address) instead of
forretningsadresse.

Each address contains: `adresse` (street lines), `postnummer` (postal
code), `poststed` (city), `kommune` (municipality name), `kommunenummer`
(4-digit municipality code), `land` (country), `landkode` (ISO country
code).

## Municipality codes and the 2020 reform

Norway reduced municipalities from 428 to 356 on January 1, 2020 (with
further changes in 2024 reverting some mergers). Historical data
contains old codes that no longer exist. Use
[`brreg_harmonize_kommune()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_harmonize_kommune.md)
to remap:

``` r
panel <- tibble::tibble(
  municipality_code = c("0301", "1201", "0602"),  # Oslo, Bergen (old), Drammen (old)
  year = 2019
)
brreg_harmonize_kommune(panel, target_date = "2024-01-01")
```

## Dates

Key date fields and their meaning:

| Column              | API field                           | Meaning                                       |
|---------------------|-------------------------------------|-----------------------------------------------|
| `founding_date`     | `stiftelsesdato`                    | Date the entity was founded/incorporated      |
| `registration_date` | `registreringsdatoEnhetsregisteret` | Date of registration in the central register  |
| `articles_date`     | `vedtektsdato`                      | Date of latest articles of association        |
| `bankruptcy_date`   | `konkursdato`                       | Date bankruptcy was opened                    |
| `liquidation_date`  | `underAvviklingDato`                | Date voluntary liquidation began              |
| `deletion_date`     | `slettedato`                        | Date the entity was deleted from the register |

`registration_date` is more reliable than `founding_date` for
determining when an entity entered the register — some entities have
founding dates predating the electronic register.

## CSV vs JSON bulk downloads

The bulk download endpoints return different column sets:

| Feature        | CSV (`/lastned/csv`)                         | JSON (`/lastned`)                                    |
|----------------|----------------------------------------------|------------------------------------------------------|
| Size (enheter) | 152 MB                                       | 196 MB                                               |
| Columns        | ~90                                          | ~67 (after flattening)                               |
| Extra fields   | Dissolution dates, foreign insolvency        | `kapital.*`, `vedtektsfestetFormaal`, `paategninger` |
| Address format | Flat (one column per field)                  | Nested (array of address lines)                      |
| Delimiter      | Comma (despite common belief it’s semicolon) | N/A                                                  |

Neither format is a superset of the other. The package’s algorithmic
unnesting produces flat tibbles from both formats. Choose JSON when you
need share capital data (`kapital.*`) or articles of association text;
choose CSV when you need dissolution details.

## CDC update stream

The change data capture endpoints track modifications to the register:

- **Enheter/Underenheter**: `/oppdateringer/{type}` returns change
  events with type (Ny/Endring/Sletting) and optional field-level RFC
  6902 patches (since September 2025).
- **Roller**: `/oppdateringer/roller` returns CloudEvents indicating
  which entities had role changes (no field detail — fetch the entity’s
  roles separately).

Field-level patches provide only new values, not old values. For
before/after comparisons, use
[`brreg_events()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_events.md)
to diff two snapshots.

## Data update schedule

The brreg bulk files are regenerated nightly. The `Last-Modified` HTTP
header on the download response indicates when the file was last
regenerated (typically between 02:00 and 06:00 CET). The CDC stream is
near-real-time during business hours.

## Data license

All data from Enhetsregisteret is freely available under the [Norwegian
Licence for Open Government Data (NLOD
2.0)](https://data.norge.no/nlod/en/2.0). No API key is required. There
is no formal rate limit, but the package applies a 5 requests/second
throttle as courtesy.
