#' Create the MCP server state
#'
#' Builds the tool catalogue and resource index from the installed
#' tidybrreg once; transports call [mcp_handle()] with it for every
#' message.
#'
#' @inheritParams mcp_tools
#' @returns An environment holding `tools`, `resources`, `info`,
#'   `instructions`, and `initialized`.
#' @export
#' @examples
#' srv <- mcp_server()
#' length(srv$tools)
mcp_server <- function(package = "tidybrreg", exclude = mcp_excluded()) {
  srv <- new.env(parent = emptyenv())
  srv$package <- package
  srv$tools <- mcp_tools(package, exclude = exclude)
  srv$resources <- mcp_resources(package)
  srv$info <- list(
    name = "tidybrreg-mcp",
    title = "tidybrreg: Norway's business registry (Enhetsregisteret)",
    version = as.character(utils::packageVersion("tidybrregmcp"))
  )
  srv$instructions <- server_instructions(package)
  srv$initialized <- FALSE
  srv
}

#' The protocol version this server speaks
#' @keywords internal
mcp_protocol_version <- function() "2025-06-18"

#' Server instructions derived from the package documentation
#'
#' The DESCRIPTION's description field, the package's documented
#' condition classes, and the data principles stated in the help pages
#' are handed to clients verbatim, so the model works with the register
#' the way tidybrreg does: codes by default, only observed fields, typed
#' conditions instead of silent partial results.
#' @keywords internal
server_instructions <- function(package = "tidybrreg") {
  desc <- utils::packageDescription(package)
  index <- rd_index(package)
  cond <- index[["tidybrreg_conditions"]]
  cond_md <- if (is.null(cond)) "" else rd_topic_md(cond, "tidybrreg_conditions")
  paste(c(
    paste0("This server exposes the R package ", package, " ", desc$Version,
           " as tools. Tool names are the package's exported function names; ",
           "every description is the function's help page."),
    gsub("\\s+", " ", desc$Description),
    "Working rules, as the package documents them:",
    "- Coded values are returned as codes (legal forms, NACE, sector, roles). Translate with brreg_label or type = \"label\" only when the user wants descriptions.",
    "- Entity results emit only the fields the register carried for that entity; a missing column means the register did not emit it, not that the value is empty.",
    "- A warning or an attribute such as complete = FALSE, total_matches, http_status or deleted = TRUE is part of the answer: report it to the user rather than presenting a slice as the whole population.",
    "- Organization numbers are 9-digit strings validated with modulus 11; quote them as strings.",
    "- Bulk downloads are large (tens to hundreds of megabytes); prefer brreg_search for interactive questions.",
    "- Register data is published by the Br\u00f8nn\u00f8ysund Register Centre under NLOD 2.0 and must be attributed when redistributed.",
    cond_md
  ), collapse = "\n\n")
}

#' Handle one JSON-RPC message
#'
#' Pure dispatcher shared by every transport. Requests return a response
#' object; notifications return `NULL`. Tool execution errors are
#' reported inside the result (`isError`), protocol errors as JSON-RPC
#' errors.
#'
#' @param srv Server state from [mcp_server()].
#' @param msg A decoded JSON-RPC message (named list).
#' @returns A named list (the response) or `NULL`.
#' @export
#' @examples
#' srv <- mcp_server()
#' mcp_handle(srv, list(jsonrpc = "2.0", id = 1, method = "ping"))
mcp_handle <- function(srv, msg) {
  id <- msg$id
  method <- msg$method
  if (is.null(method) || !is.character(method)) {
    return(rpc_error(id, -32600L, "Invalid Request: missing method"))
  }
  params <- msg$params %||% list()
  is_notification <- is.null(id)

  result <- tryCatch(
    switch(method,
      "initialize" = {
        srv$initialized <- TRUE
        list(
          protocolVersion = negotiate_version(params$protocolVersion),
          capabilities = list(
            tools = list(listChanged = FALSE),
            resources = list(subscribe = FALSE, listChanged = FALSE)
          ),
          serverInfo = srv$info,
          instructions = srv$instructions
        )
      },
      "notifications/initialized" = NULL,
      "notifications/cancelled" = NULL,
      "ping" = structure(list(), names = character()),
      "tools/list" = list(tools = tools_public(srv$tools)),
      "tools/call" = {
        name <- params$name
        tool <- srv$tools[[name %||% ""]]
        if (is.null(tool)) {
          return(rpc_error(id, -32602L, paste0("Unknown tool: ", name %||% "<missing>")))
        }
        call_tool(tool, params$arguments)
      },
      "resources/list" = list(resources = resources_public(srv$resources)),
      "resources/templates/list" = list(resourceTemplates = list()),
      "resources/read" = {
        res <- srv$resources[[params$uri %||% ""]]
        if (is.null(res)) {
          return(rpc_error(id, -32002L, paste0("Resource not found: ", params$uri %||% "<missing>")))
        }
        list(contents = list(list(uri = res$uri, mimeType = res$mimeType, text = res$read())))
      },
      "prompts/list" = list(prompts = list()),
      "logging/setLevel" = structure(list(), names = character()),
      return(rpc_error(id, -32601L, paste0("Method not found: ", method)))
    ),
    error = function(e) rpc_error(id, -32603L, paste0("Internal error: ", conditionMessage(e)))
  )
  if (is_notification) return(NULL)
  if (!is.null(result) && identical(result$jsonrpc, "2.0") && !is.null(result$error)) return(result)
  list(jsonrpc = "2.0", id = id, result = result)
}

#' @keywords internal
negotiate_version <- function(requested) {
  supported <- c("2025-06-18", "2025-03-26", "2024-11-05")
  if (!is.null(requested) && requested %in% supported) requested else mcp_protocol_version()
}

#' @keywords internal
rpc_error <- function(id, code, message) {
  list(jsonrpc = "2.0", id = id, error = list(code = code, message = message))
}

#' Resources: help pages, bundled datasets, provenance and news
#'
#' Every help topic of tidybrreg is a Markdown resource, each bundled
#' dataset a JSON resource, and the package NEWS and README text
#' resources. URIs use the `tidybrreg://` scheme.
#' @keywords internal
mcp_resources <- function(package = "tidybrreg") {
  index <- rd_index(package)
  db <- tools::Rd_db(package)
  res <- list()
  add <- function(uri, name, title, mimeType, read, description = NULL) {
    res[[uri]] <<- list(uri = uri, name = name, title = title, mimeType = mimeType,
                        description = description, read = read)
  }
  for (nm in names(db)) {
    rd <- db[[nm]]
    topic <- sub("\\.Rd$", "", nm)
    title <- md_tidy(rd_md(rd_section(rd, "\\title")))
    add(paste0("tidybrreg://docs/", topic), paste0("docs/", topic), title, "text/markdown",
        local({ rd <- rd; topic <- topic; function() rd_topic_md(rd, topic) }),
        description = paste0("Help page ", topic, " of ", package))
  }
  for (ds in utils::data(package = package)$results[, "Item"]) {
    add(paste0("tidybrreg://data/", ds), paste0("data/", ds), paste0("Bundled dataset ", ds),
        "application/json",
        local({ ds <- ds; pkg <- package; function() {
          as.character(jsonlite::toJSON(getExportedValue(pkg, ds), dataframe = "rows",
                                        na = "null", auto_unbox = TRUE, pretty = TRUE))
        } }),
        description = paste0("Reference table ", ds, " as JSON rows"))
  }
  for (f in c("NEWS.md", "README.md")) {
    path <- system.file(f, package = package)
    if (nzchar(path)) {
      add(paste0("tidybrreg://", tolower(sub("\\.md$", "", f))), tolower(sub("\\.md$", "", f)),
          paste0(package, " ", f), "text/markdown",
          local({ path <- path; function() paste(readLines(path, warn = FALSE), collapse = "\n") }))
    }
  }
  res
}

#' @keywords internal
resources_public <- function(resources) {
  unname(lapply(resources, function(r) {
    out <- r[c("uri", "name", "title", "mimeType")]
    if (!is.null(r$description)) out$description <- r$description
    out
  }))
}
