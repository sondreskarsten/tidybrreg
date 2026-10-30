#' Serve tidybrreg over the Model Context Protocol
#'
#' Starts an MCP server whose tools are tidybrreg's exported functions
#' (see [mcp_tools()]). Two transports are available.
#'
#' @section stdio:
#' `transport = "stdio"` reads newline-delimited JSON-RPC messages from
#' standard input and writes responses to standard output, which is what
#' desktop clients (Claude Desktop, Claude Code, Cursor, ...) expect
#' from a locally launched server. Log lines go to standard error. A
#' client configuration is:
#'
#' ```
#' {"mcpServers": {"tidybrreg": {"command": "Rscript",
#'   "args": ["-e", "tidybrregmcp::mcp_serve()"]}}}
#' ```
#'
#' @section Streamable HTTP:
#' `transport = "http"` serves the streamable HTTP transport with
#' httpuv: `POST /mcp` carries one JSON-RPC message (or a batch) and
#' answers with `application/json`; `GET /mcp` answers 405 because this
#' server never pushes messages; `DELETE /mcp` ends a session;
#' `GET /health` reports the server and the tidybrreg version. When the
#' `MCP_BEARER_TOKEN` environment variable (or `token`) is set, every
#' `/mcp` request must carry it as `Authorization: Bearer`.
#'
#' @param transport `"stdio"` (default) or `"http"`.
#' @param host,port Bind address for the HTTP transport. `port` defaults
#'   to the `PORT` environment variable (as set by Cloud Run) or 8080.
#' @param token Bearer token for the HTTP transport; `NULL` or `""`
#'   disables authentication.
#' @param srv Server state; built with [mcp_server()] when `NULL`.
#'
#' @returns `mcp_serve()` runs until the client closes the connection
#'   (stdio) or the process is interrupted (HTTP) and then returns
#'   `invisible(NULL)`.
#' @export
#' @examples
#' \dontrun{
#' tidybrregmcp::mcp_serve()
#' tidybrregmcp::mcp_serve("http", port = 8080)
#' }
mcp_serve <- function(transport = c("stdio", "http"),
                      host = "0.0.0.0",
                      port = as.integer(Sys.getenv("PORT", "8080")),
                      token = Sys.getenv("MCP_BEARER_TOKEN", ""),
                      srv = NULL) {
  transport <- match.arg(transport)
  srv <- srv %||% mcp_server()
  switch(transport,
    stdio = serve_stdio(srv),
    http = serve_http(srv, host = host, port = port, token = token)
  )
}

#' @keywords internal
log_line <- function(...) {
  cat(format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), ..., "\n", file = stderr())
}

#' @keywords internal
encode_msg <- function(x) {
  as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null", na = "null", digits = NA))
}

#' @keywords internal
decode_msg <- function(txt) {
  tryCatch(jsonlite::fromJSON(txt, simplifyVector = FALSE), error = function(e) NULL)
}

#' Dispatch a decoded message or batch
#' @keywords internal
dispatch <- function(srv, parsed) {
  if (is.null(parsed)) return(rpc_error(NULL, -32700L, "Parse error"))
  if (is.list(parsed) && is.null(names(parsed))) {
    out <- Filter(Negate(is.null), lapply(parsed, function(m) mcp_handle(srv, m)))
    if (length(out) == 0) return(NULL)
    return(out)
  }
  mcp_handle(srv, parsed)
}

#' @keywords internal
serve_stdio <- function(srv) {
  log_line("tidybrreg-mcp stdio server:", length(srv$tools), "tools from tidybrreg",
           as.character(utils::packageVersion(srv$package)))
  con <- file("stdin", open = "r", blocking = TRUE)
  on.exit(close(con), add = TRUE)
  repeat {
    line <- readLines(con, n = 1L, warn = FALSE)
    if (length(line) == 0) break
    if (!nzchar(trimws(line))) next
    response <- dispatch(srv, decode_msg(line))
    if (!is.null(response)) {
      cat(encode_msg(response), "\n", sep = "")
      flush(stdout())
    }
  }
  invisible(NULL)
}

#' @keywords internal
serve_http <- function(srv, host, port, token) {
  rlang::check_installed("httpuv", reason = "for the HTTP transport")
  token <- if (is.null(token) || !nzchar(token)) NULL else token
  app <- list(call = function(req) http_call(srv, req, token))
  log_line("tidybrreg-mcp http server on", paste0(host, ":", port), "with",
           length(srv$tools), "tools; auth", if (is.null(token)) "off" else "on")
  httpuv::runServer(host, port, app)
  invisible(NULL)
}

#' Rook-style request handler for the HTTP transport
#' @keywords internal
http_call <- function(srv, req, token = NULL) {
  path <- req$PATH_INFO %||% "/"
  method <- req$REQUEST_METHOD %||% "GET"
  json <- function(status, body, headers = list()) {
    list(status = status,
         headers = c(list("Content-Type" = "application/json"), headers),
         body = encode_msg(body))
  }
  if (path == "/health" && method == "GET") {
    return(json(200L, list(status = "ok", server = srv$info$name, version = srv$info$version,
                           tidybrreg = as.character(utils::packageVersion(srv$package)),
                           tools = length(srv$tools))))
  }
  if (path != "/mcp") return(json(404L, list(error = "not found")))
  if (!is.null(token)) {
    auth <- req$HTTP_AUTHORIZATION %||% ""
    if (!identical(auth, paste("Bearer", token))) {
      return(json(401L, list(error = "unauthorized"),
                  headers = list("WWW-Authenticate" = "Bearer")))
    }
  }
  if (method == "GET") {
    return(list(status = 405L, headers = list("Allow" = "POST, DELETE"), body = ""))
  }
  if (method == "DELETE") return(list(status = 200L, headers = list(), body = ""))
  if (method != "POST") return(list(status = 405L, headers = list("Allow" = "POST, DELETE"), body = ""))

  body <- req$rook.input$read()
  txt <- if (length(body) == 0) "" else rawToChar(body)
  Encoding(txt) <- "UTF-8"
  response <- dispatch(srv, decode_msg(txt))
  if (is.null(response)) return(list(status = 202L, headers = list(), body = ""))
  session <- req$HTTP_MCP_SESSION_ID %||% srv$session_id %||% {
    srv$session_id <- paste0("tidybrreg-", as.integer(Sys.time()))
    srv$session_id
  }
  json(200L, response, headers = list("Mcp-Session-Id" = session))
}
