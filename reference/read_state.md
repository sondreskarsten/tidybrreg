# Read current state for a registry type

Loads state from parquet, caching in `.brregEnv` for the session.
Returns `NULL` if no state file exists.

## Usage

``` r
read_state(type, use_cache = TRUE)
```

## Arguments

- type:

  One of `"enheter"`, `"underenheter"`, `"roller"`, `"paategninger"`.

- use_cache:

  Logical. Use session cache if available.

## Value

A tibble or `NULL`.
