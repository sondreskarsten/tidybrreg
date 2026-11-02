# Signal a typed tidybrreg warning

Signal a typed tidybrreg warning

## Usage

``` r
brreg_warn(
  message,
  class,
  ...,
  call = rlang::caller_env(),
  .envir = parent.frame()
)
```

## Arguments

- message:

  A cli-formatted message vector.

- class:

  Condition subclass (without the `tidybrreg_error_` prefix).

- ...:

  Fields stored on the condition object.

- call:

  Calling environment reported by cli.

- .envir:

  Environment in which the message's
  [`{}`](https://rdrr.io/r/base/Paren.html) expressions are evaluated;
  defaults to the caller of this helper.
