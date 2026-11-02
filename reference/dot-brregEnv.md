# Session-level dictionary cache (eurostat pattern)

Holds dictionaries fetched from SSB KLASS by
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md)
for the duration of the session, plus the HTTP metadata of the most
recent
[`brreg_download()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_download.md).
Nothing is read from or written to disk at load time; loading or
attaching the package performs no network request and creates no
directory.

## Usage

``` r
.brregEnv
```

## Format

An object of class `environment` of length 0.
