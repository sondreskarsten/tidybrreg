# tidybrreg-mcp (Node)

A [Model Context Protocol](https://modelcontextprotocol.io) server for
Norway's business registry (Enhetsregisteret) that runs **without R**,
for Claude Desktop, Claude Code, ChatGPT, the OpenAI Agents SDK and any
other MCP client.

It is not a second implementation of the register. Everything it serves
comes from `manifest.json`, which `tidybrregmcp::mcp_manifest()` writes
from the installed [tidybrreg](https://github.com/sondreskarsten/tidybrreg)
R package:

| From tidybrreg | In this server |
|---|---|
| the 15 exported functions | the 15 tools, same names |
| each function's help page | tool title, description, argument descriptions |
| formals + `@param` types | input JSON schema (enums, defaults, required) |
| `inst/extdata/endpoints.json` (tested against the functions in R) | which URL each tool calls, query-parameter mapping, pagination and status contract |
| `field_dict`, `legal_forms`, `role_types`, `role_groups`, bundled NACE and sector codes | column renaming, type coercion, labels, offline dictionaries (with vintage) |
| `?tidybrreg_conditions` | the condition classes reported in results and errors |
| every help topic, provenance, NEWS | `tidybrreg://` resources and the server instructions |

The TypeScript port of the parsing rules (observed fields only, HAL
stripping, `"\n"` array collapse, dictionary coercion with reported
failures, deletion on 200 and 410, the 10,000 result window, cursor
pagination, UTC instants) is covered by tests that use the same fixtures
as tidybrreg's own suite, and CI fails if regenerating the manifest from
the R package changes anything. Same tidybrreg version, same catalogue.

## Install and run

```bash
npx tidybrreg-mcp            # stdio
npx tidybrreg-mcp --http 8080
```

Or `npm install -g tidybrreg-mcp`. Node 20 or newer; no other runtime.

### Claude Desktop / Claude Code / Cursor

```json
{
  "mcpServers": {
    "tidybrreg": { "command": "npx", "args": ["-y", "tidybrreg-mcp"] }
  }
}
```

```
claude mcp add tidybrreg -- npx -y tidybrreg-mcp
```

### ChatGPT connectors and the OpenAI Responses API (remote MCP)

Run the HTTP transport somewhere reachable (the repository's Cloud Run
service exposes the same catalogue) and point the client at `/mcp`:

```json
{
  "type": "mcp",
  "server_label": "tidybrreg",
  "server_url": "https://<host>/mcp",
  "headers": {"Authorization": "Bearer <token>"},
  "require_approval": "never"
}
```

### OpenAI Agents SDK (local, stdio)

```python
from agents.mcp import MCPServerStdio
async with MCPServerStdio(params={"command": "npx", "args": ["-y", "tidybrreg-mcp"]}) as server:
    ...
```

## What the tools return

Every tool answers with a text block and `structuredContent`:

```json
{"tool": "brreg_search", "kind": "table", "rows": [...], "n_rows": 5, "n_total": 93,
 "columns": [{"name": "org_nr", "type": "character"}, ...],
 "attributes": {"total_matches": 93, "complete": false},
 "conditions": [{"kind": "warning", "class": "tidybrreg_warning_truncated", "message": "...", "fields": {...}}]}
```

Codes stay codes unless `type = "label"` or `brreg_label` is used;
columns are tidybrreg's English names; a missing column means the
register did not emit that field. Errors come back as `isError` results
carrying the tidybrreg condition class and fields
(`tidybrreg_error_result_window`, `tidybrreg_error_not_found`, ...).

Four optional arguments shape output: `.limit` (default 200), `.offset`,
`.columns`, `.format` (`records`, `csv`, `markdown`).

`brreg_download` without R downloads the bulk file into the cache
directory and returns its path; `type_output = "tibble"` additionally
returns a 20-row preview and says so, because a million-row table cannot
travel over MCP.

## Environment

| Variable | Effect |
|---|---|
| `TIDYBRREG_MCP_EXCLUDE` | comma-separated tools to drop (for example `brreg_download`) |
| `TIDYBRREG_OFFLINE=1` | never call SSB KLASS; bundled English dictionaries only |
| `TIDYBRREG_CACHE_DIR` | where bulk downloads are cached |
| `MCP_BEARER_TOKEN` / `--token` | require a bearer token on `/mcp` |
| `PORT` / `--http PORT` | HTTP transport port |
| `TIDYBRREG_MCP_MAX_ROWS` | upper bound for `.limit` (default 5000) |

## Development

```bash
npm install
npm run build
npm test
Rscript -e 'tidybrregmcp::mcp_manifest("manifest.json")'   # after any tidybrreg change
npm run check:manifest                                      # what CI runs
```

Releases: the `release` workflow publishes this package to npm and
attaches the tarball and manifest to the GitHub release whenever a
`v*` tag is pushed on a green `main`; the version must equal
tidybrreg's.
