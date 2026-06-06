# Query the current CDC tip (max event ID) for a stream

Used during bootstrap to initialize the cursor at the current position,
preventing the first CDC poll from replaying the entire event history.

## Usage

``` r
get_cdc_tip(type)
```

## Arguments

- type:

  One of `"enheter"`, `"underenheter"`, `"roller"`.

## Value

Integer max event ID, or 0L if the endpoint is empty.
