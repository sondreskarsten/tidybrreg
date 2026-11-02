# Validate Norwegian organization numbers

Check whether organization numbers (organisasjonsnummer) pass the
modulus-11 check digit algorithm used by Norway's Central Coordinating
Register for Legal Entities. Valid numbers are exactly 9 digits, start
with 8 or 9 (the series the register allocates from), and have a correct
check digit computed with weights `3, 2, 7, 6, 5, 4, 3, 2`.

## Usage

``` r
brreg_validate(org_nr)
```

## Arguments

- org_nr:

  Character vector of organization numbers to validate.

## Value

Logical vector the same length as `org_nr`. `TRUE` for valid numbers,
`FALSE` otherwise (including `NA` input).

## See also

[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)
which validates before querying the API.

Other tidybrreg utilities:
[`brreg_label()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_label.md),
[`get_brreg_dic()`](https://sondreskarsten.github.io/tidybrreg/reference/get_brreg_dic.md),
[`tidybrreg_conditions`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_conditions.md),
[`tidybrreg_endpoints`](https://sondreskarsten.github.io/tidybrreg/reference/tidybrreg_endpoints.md)

## Examples

``` r
brreg_validate(c("923609016", "984851006", "123456789", "999999999"))
#> [1]  TRUE  TRUE FALSE  TRUE
```
