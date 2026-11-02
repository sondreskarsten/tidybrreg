# Download the full Norwegian business register

Download a complete extract of the Central Coordinating Register for
Legal Entities (~1 million entities, ~150 MB gzipped). The bulk endpoint
does not support server-side filtering — it always returns all entities.
Use
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for filtered queries up to 10,000 results, or download the full register
here and filter locally.

## Usage

``` r
brreg_download(
  type = c("enheter", "underenheter", "roller"),
  refresh = FALSE,
  cache = TRUE,
  type_output = c("tibble", "path")
)
```

## Arguments

- type:

  One of `"enheter"` (main entities, default, ~196 MB), `"underenheter"`
  (sub-entities / establishments, ~75 MB), or `"roller"` (all roles for
  all entities via `/roller/totalbestand`, ~131 MB). All three are
  gzipped JSON.

- refresh:

  `FALSE` (default): use cached file if available. `TRUE`: force
  re-download. `"auto"`: revalidate against the server and re-download
  only when the cached copy cannot be shown current. Any other value is
  an error.

- cache:

  Logical. If `TRUE` (default), keep the downloaded file in the
  persistent cache directory; if `FALSE`, use a temporary file.

- type_output:

  One of `"tibble"` (default) or `"path"` (returns the file path without
  parsing).

## Value

Depends on `type_output`:

- `"tibble"`: A tibble with ~1 million rows. Column names mapped via
  [field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md);
  arrays of objects are list-columns of tibbles. For `type = "roller"`,
  one row per role assignment with the columns of
  [`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md).

- `"path"`: Character file path to the gzipped download.

## Backend routing

The brreg API has two data access paths with fundamentally different
characteristics, following the cansim (Statistics Canada) pattern of
separate functions for separate access patterns rather than the eurostat
pattern of auto-routing within one function:

- **[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)**:
  JSON API with server-side filtering. Fast for small result sets,
  capped at 10,000. Interactive exploration.

- **`brreg_download()`**: Bulk JSON. Always returns the full register.
  Appropriate for any analysis requiring more than 10,000 entities.

Results from both paths use the same column names and types via
[field_dict](https://sondreskarsten.github.io/tidybrreg/reference/field_dict.md);
only observed columns are emitted (see
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md)).
The bulk is the JSON variant of each endpoint, the same representation
the single-entity lookups and the update feeds use, so `historiskeNavn`
and `paategninger` arrive as the nested list-columns `historiske_navn`
and `annotations` exactly as from
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md).
BRREG's CSV variant is not read: it is the register's own flattening,
with different separators and a presence flag in place of the annotation
array.

## Memory and time

The tibble of the full register is built in memory. The gzipped array is
decoded in batches of complete objects and the batches are bound one
column at a time, so the peak is the result plus the decoder's transient
rather than a multiple of the result. Measured on the live register on
2026-11-02 (2 cores): `enheter`, 1,179,853 rows and 91 columns, 14.6
minutes, a 1.6 GB tibble, 4.0 GB peak resident memory; `underenheter`,
870,571 rows and 43 columns, 7.1 minutes, 0.9 GB, 2.0 GB peak; `roller`,
3,426,438 roles of 1,154,321 entities, 11.1 minutes, 0.7 GB, 2.3 GB peak
with jsonlite (yyjsonr, when installed, decodes each batch faster). A
machine with 8 GB holds one full `enheter` parse and not two at once.
`type_output = "path"` costs nothing beyond the download, and
`parse_bulk_json(path, n_max = )` (internal) reads the head of the array
without inflating the rest.

## Caching

With `cache = TRUE` (default) the gzipped payload is stored in
`tools::R_user_dir("tidybrreg", "cache")` together with a sidecar
recording the server's `ETag` and `Last-Modified` validators, and a
later call reuses it. `refresh = TRUE` forces a new download.
`refresh = "auto"` sends a HEAD request and re-downloads when either
validator differs from the sidecar; when the sidecar is missing or the
server sends neither validator, nothing can prove the cache current, so
it is re-downloaded. With `cache = FALSE` the payload goes to a
temporary file that is deleted after parsing; with
`type_output = "path"` that temporary path is returned and the caller
owns it. The cache directory is created only by this function, never at
load time.

Metadata of the most recent download (`url`, `etag`, `last_modified` as
a UTC `POSIXct`, `downloaded_at`, `path`) is available as
`attr(result, "brreg_download")` on tibble output.

## Tidy shape

Every tibble the package returns is tidy in Wickham's sense: one
observation per row, one variable per column, one observational unit per
table. The register nests two kinds of array inside an entity. Arrays of
strings (`business_address`, `postal_address`, `location_address`,
`purpose`, `activity`) are the line fragments of one value and are
joined with `"\n"`, which no fragment contains, so `strsplit(x, "\n")`
recovers the lines. Arrays of objects (`historiske_navn`, `annotations`,
any array of objects the register adds) are observations of another unit
and are nested as a list-column of tibbles, one row per element with
snake_case columns, `NULL` for an entity without them;
[`tidyr::unnest()`](https://tidyr.tidyverse.org/reference/unnest.html)
expands them to their own table. An empty array is not an observation
and emits no column. Nothing is serialized to JSON text.

## See also

[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md)
for filtered API queries,
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)
for incremental changes since a given date.

Other tidybrreg entity functions:
[`brreg_children()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_children.md),
[`brreg_entity()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_entity.md),
[`brreg_konsern()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_konsern.md),
[`brreg_prokura()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_prokura.md),
[`brreg_regnskap()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_regnskap.md),
[`brreg_roles()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles.md),
[`brreg_roles_legal()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_roles_legal.md),
[`brreg_search()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_search.md),
[`brreg_signatur()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_signatur.md),
[`brreg_underenheter()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_underenheter.md),
[`brreg_update_fields()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_update_fields.md),
[`brreg_updates()`](https://sondreskarsten.github.io/tidybrreg/reference/brreg_updates.md)

## Examples

``` r
if (FALSE) { # interactive() && curl::has_internet()
# \donttest{
# Download full register as tibble (~196 MB download, ~1M rows)
entities <- brreg_download()

# Just get the file path (no parsing)
path <- brreg_download(type_output = "path")

# Force refresh
entities <- brreg_download(refresh = TRUE)
# }
}
```
