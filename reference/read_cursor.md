# Read the sync cursor

The cursor tracks the last-seen `oppdateringsid` for each CDC stream and
the last sync timestamp. Stored as JSON in `state/sync_cursor.json`.

## Usage

``` r
read_cursor()
```

## Value

A list with `enheter_id`, `underenheter_id`, `roller_id`, `last_sync`.
Returns defaults if no cursor exists.
