# Fetch classification labels from SSB Klass API

Fetch classification labels from SSB Klass API

## Usage

``` r
fetch_klass(classification_id, lang = "en", date = Sys.Date())
```

## Arguments

- classification_id:

  Integer. SSB Klass classification ID (6 = SN2007/NACE, 39 =
  institutional sector).

- lang:

  Language code: `"en"` or `"no"`. KLASS names its languages `en`, `nb`
  and `nn`; `"no"` is sent as `nb` (Bokmål).

- date:

  Date for which codes are valid.

## Value

A tibble with columns `code`, `name`, `level`.
