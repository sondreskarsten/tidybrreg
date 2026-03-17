# Fetch English classification labels from SSB Klass API

Fetch English classification labels from SSB Klass API

## Usage

``` r
fetch_klass(classification_id, lang = "en", date = Sys.Date())
```

## Arguments

- classification_id:

  Integer. SSB Klass classification ID (6 = SN2007/NACE, 39 =
  institutional sector).

- lang:

  Language code: `"en"` or `"no"`.

- date:

  Date for which codes are valid.

## Value

A tibble with columns `code`, `name_en`, `level`.
