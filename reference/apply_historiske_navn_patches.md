# Apply historiskeNavn JSON Patch operations to the name-history state

The oppdateringer feed emits `add /historiskeNavn/-` patches whose value
object carries the superseded name and its validity interval (`navn`,
`fraDato`, `tilDato`).
[`parse_patch()`](https://sondreskarsten.github.io/tidybrreg/reference/parse_patch.md)
flattens these to `historiskeNavn_-_navn` etc. Name history only ever
appends — there is no clear semantics as with påtegninger — so this
applier handles appends only. Emitted for both enheter and underenheter.

## Usage

``` r
apply_historiske_navn_patches(
  hist_state,
  org_nr,
  patches,
  timestamp,
  update_id
)
```

## Arguments

- hist_state:

  Current historiske_navn state tibble.

- org_nr:

  Organization number the patches apply to.

- patches:

  Parsed patch tibble subset (fields starting `historiskeNavn`).

- timestamp:

  Event timestamp (passed to changelog).

- update_id:

  CDC update id (passed to changelog).

## Value

List with `state` (updated tibble) and `changelog`.
