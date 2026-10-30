# tidybrregmcp

A [Model Context Protocol](https://modelcontextprotocol.io) server for
Norway's business registry, derived entirely from the
[tidybrreg](https://github.com/sondreskarsten/tidybrreg) R package.

The server has no catalogue of its own. At start-up it reads the installed
tidybrreg namespace and help pages and builds one tool per exported
function:

| From tidybrreg | Becomes |
|---|---|
| exported function name | tool name |
| `\title` of the help page | tool title |
| description, details, sections, value | tool description (Markdown) |
| formals + `@param` text | input JSON schema (types, enums, defaults, required) |
| the tibble the function returns | `structuredContent.rows`, with tidybrreg's column names and codes |
| attributes (`total_matches`, `complete`, `http_status`, `cursor`, ...) | `structuredContent.attributes` |
| typed warnings and messages (`tidybrreg_warning_*`) | `structuredContent.conditions` |
| typed errors (`tidybrreg_error_*`) | `isError = true` with class and fields |
| every help topic, bundled dataset, NEWS and README | resources under `tidybrreg://` |
| DESCRIPTION + `?tidybrreg_conditions` | server `instructions` |

So when tidybrreg gains an export, changes an argument, or rewrites a
help page, the MCP catalogue changes with it. A test asserts the tool
list equals `getNamespaceExports("tidybrreg")` and that the two packages
share a version, and the Docker image is built from the same commit as
tidybrreg on every push to `main`.

The server adds exactly four optional arguments to every tool, all
prefixed with a dot so they cannot collide with tidybrreg's: `.limit`
(rows returned, default 200), `.offset`, `.columns`, and `.format`
(`records`, `csv`, `markdown`). The structured result always carries
`n_total`, so a slice is never mistaken for the population.

## Install

```r
install.packages(c("tidybrreg", "tidybrregmcp"),
  repos = c("https://sondreskarsten.r-universe.dev", "https://cloud.r-project.org"))
```

## Run locally (stdio)

Claude Desktop / Claude Code / Cursor configuration:

```json
{
  "mcpServers": {
    "tidybrreg": {
      "command": "Rscript",
      "args": ["-e", "tidybrregmcp::mcp_serve()"]
    }
  }
}
```

Or with Claude Code:

```
claude mcp add tidybrreg -- Rscript -e "tidybrregmcp::mcp_serve()"
```

## Run as a service (streamable HTTP)

```r
tidybrregmcp::mcp_serve("http", port = 8080)
```

`POST /mcp` carries JSON-RPC; `GET /health` reports versions. Set
`MCP_BEARER_TOKEN` to require `Authorization: Bearer`. The image in
`Dockerfile` runs the same server (`MCP_TRANSPORT=http`), and
`deploy/cloud-run.yaml` is the Cloud Run service definition used by the
`mcp-image` GitHub workflow.

Remote client configuration:

```json
{
  "mcpServers": {
    "tidybrreg": {
      "type": "http",
      "url": "https://<cloud-run-host>/mcp",
      "headers": {"Authorization": "Bearer <token>"}
    }
  }
}
```

## Exclusions

`TIDYBRREG_MCP_EXCLUDE="brreg_download"` (comma-separated) removes tools
from the catalogue without changing anything else, for deployments where
a 150 MB bulk download is not appropriate.

## Design notes

- The server never interprets register data. It calls tidybrreg and
  serialises what tidybrreg returns. Codes stay codes unless the tool's
  own `type = "label"` or the `brreg_label` tool is used.
- Everything a model needs to use the register responsibly is in the
  tool descriptions because it is in the help pages: observed-fields
  emission, the 10,000-result window, deletion semantics, the
  completeness attributes, the condition classes.
- The server is deliberately small: `R/rd.R` (Rd to Markdown),
  `R/tools.R` (schema derivation), `R/execute.R` (call and shape),
  `R/server.R` (JSON-RPC dispatch), `R/transport.R` (stdio, HTTP).
