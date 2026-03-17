# Download the full Norwegian business register

Download a complete extract of the Central Coordinating Register for
Legal Entities (~1 million entities, ~145 MB gzipped). The bulk endpoint
does not support server-side filtering — it always returns all entities.
Use
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for filtered queries up to 10,000 results, or download the full register
here and filter locally.

## Usage

``` r
brreg_download(
  type = c("enheter", "underenheter", "roller"),
  format = c("csv", "json"),
  refresh = FALSE,
  cache = TRUE,
  type_output = c("tibble", "arrow", "path")
)
```

## Arguments

- type:

  One of `"enheter"` (main entities, default), `"underenheter"`
  (sub-entities / establishments), or `"roller"` (all roles for all
  entities). Roller data is only available as JSON via
  `/roller/totalbestand` (~131 MB).

- format:

  Download format: `"csv"` (default for enheter/underenheter,
  semicolon-delimited) or `"json"` (JSON array). Roller bulk download is
  always JSON regardless of this parameter.

- refresh:

  `FALSE` (default): use cached file if available. `TRUE`: force
  re-download. `"auto"`: check ETag and re-download only if server has a
  newer version.

- cache:

  Logical. If `TRUE` (default), cache downloaded file persistently.

- type_output:

  One of `"tibble"` (default), `"arrow"` (requires the arrow package),
  or `"path"` (returns the file path without parsing).

## Value

Depends on `type_output`:

- `"tibble"`: A tibble with ~1 million rows. Column names mapped via
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).

- `"arrow"`: An Arrow Table (lazy, not loaded into memory).

- `"path"`: Character file path to the cached CSV.

## Backend routing

The brreg API has two data access paths with fundamentally different
characteristics, following the cansim (Statistics Canada) pattern of
separate functions for separate access patterns rather than the eurostat
pattern of auto-routing within one function:

- **[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)**:
  JSON API with server-side filtering. Fast for small result sets,
  capped at 10,000. Interactive exploration.

- **`brreg_download()`**: Bulk CSV. Always returns the full register.
  Appropriate for panel construction, spatial joins, or any analysis
  requiring more than 10,000 entities.

Results from both paths use the same column names via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md).

## Caching

Downloaded files are cached in `tools::R_user_dir("tidybrreg", "cache")`
as gzipped CSV. Use `refresh = TRUE` to force re-download, or
`refresh = "auto"` to re-download only if the cached file is older than
the latest nightly bulk export (checked via ETag headers, following the
cansim `refresh = "auto"` pattern).

## See also

[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for filtered API queries,
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
for incremental changes since a given date.

Other tidybrreg entity functions:
[`brreg_board_summary()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_board_summary.md),
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
# Download full register as tibble (~145MB download, ~1M rows)
entities <- brreg_download()

# Just get the file path (no parsing)
path <- brreg_download(type_output = "path")

# Force refresh
entities <- brreg_download(refresh = TRUE)
# }
}
```
