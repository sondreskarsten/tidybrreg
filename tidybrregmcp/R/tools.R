#' MCP tool definitions derived from the tidybrreg namespace
#'
#' Every exported function of tidybrreg becomes one tool. The tool's
#' title, description and argument documentation are rendered from the
#' function's installed help page, the input schema is inferred from the
#' function's formals together with the documented argument types, and
#' nothing is hand-written per tool. A change to tidybrreg's exports or
#' documentation changes the catalogue the next time the server starts.
#'
#' @section Output shaping:
#' Four optional arguments that tidybrreg does not have are added to every
#' tool by the server, all prefixed with a dot so they can never collide
#' with a tidybrreg argument:
#' - `.limit`: maximum rows returned (default 200, at most
#'   `getOption("tidybrregmcp.max_rows", 5000)`).
#' - `.offset`: rows to skip before returning (default 0).
#' - `.columns`: column names to keep, in tidybrreg's English names.
#' - `.format`: `"records"` (default, JSON objects), `"csv"`, or
#'   `"markdown"` for the text rendering of the rows.
#' The structured result always reports the total row count so a caller
#' knows when it saw a slice.
#'
#' @param package Package whose exports become tools. Only `"tidybrreg"`
#'   is supported; the argument exists so the derivation is visibly
#'   generic.
#' @param exclude Character vector of export names not to expose. Defaults
#'   to the comma-separated `TIDYBRREG_MCP_EXCLUDE` environment variable.
#'
#' @returns A named list of tool definitions, each a list with `name`,
#'   `title`, `description`, `inputSchema`, `outputSchema`,
#'   `annotations`, and (not sent to clients) `fn` and `arg_info`.
#' @export
#' @examples
#' tools <- mcp_tools()
#' names(tools)
#' tools$brreg_entity$inputSchema$properties$registry
mcp_tools <- function(package = "tidybrreg",
                      exclude = mcp_excluded()) {
  exports <- sort(getNamespaceExports(package))
  exports <- setdiff(exports, exclude)
  index <- rd_index(package)
  tools <- lapply(exports, function(nm) {
    fn <- getExportedValue(package, nm)
    rd <- index[[nm]]
    if (is.null(rd)) {
      cli::cli_abort("No help page found for {.fn {package}::{nm}}; every export must be documented.")
    }
    tool_from_function(nm, fn, rd_doc(rd), package)
  })
  stats::setNames(tools, exports)
}

#' Exclusions read from the environment
#' @keywords internal
mcp_excluded <- function() {
  x <- Sys.getenv("TIDYBRREG_MCP_EXCLUDE", "")
  x <- trimws(strsplit(x, ",")[[1]])
  x[nzchar(x)]
}

#' Build one tool definition
#' @keywords internal
tool_from_function <- function(name, fn, doc, package) {
  fm <- formals(fn)
  arg_info <- lapply(names(fm), function(a) {
    arg_schema(a, fm[[a]], doc$arguments[[a]] %||% "")
  })
  names(arg_info) <- names(fm)
  required <- names(fm)[vapply(arg_info, function(i) isTRUE(i$required), logical(1))]
  props <- lapply(arg_info, function(i) i$schema)
  shaping <- shaping_schema()
  input <- list(
    type = "object",
    properties = c(props, shaping),
    additionalProperties = FALSE
  )
  if (length(required) > 0) input$required <- as.list(required)

  desc_parts <- c(doc$description)
  if (nzchar(doc$details)) desc_parts <- c(desc_parts, doc$details)
  for (s in names(doc$sections)) desc_parts <- c(desc_parts, paste0("**", s, ".** ", doc$sections[[s]]))
  if (nzchar(doc$value)) desc_parts <- c(desc_parts, paste0("**Returns.** ", doc$value))
  desc_parts <- c(desc_parts, paste0(
    "**Output shaping (server-side).** `.limit` rows (default 200), `.offset`, `.columns`, ",
    "`.format` (records, csv, markdown). The structured result reports `n_total`, the ",
    "attributes tidybrreg attached (for example `total_matches`, `complete`, `http_status`) ",
    "and every warning tidybrreg signalled, with its condition class."
  ))

  list(
    name = name,
    title = doc$title,
    description = paste(desc_parts, collapse = "\n\n"),
    inputSchema = input,
    outputSchema = output_schema(),
    annotations = list(
      title = doc$title,
      readOnlyHint = TRUE,
      destructiveHint = FALSE,
      idempotentHint = TRUE,
      openWorldHint = TRUE
    ),
    fn = fn,
    arg_info = arg_info,
    package = package
  )
}

#' Infer a JSON schema for one formal argument
#'
#' Rules, in order: a `c("a", "b")` default is an enumeration whose
#' default is the first value; a logical default is boolean; a numeric
#' default is a number, or an integer when the documentation says so; a
#' string default is a string; a missing default makes the argument
#' required; otherwise the documented type decides (`Character`,
#' `Integer`, `Logical`, `Date`/`POSIXct`, `character vector` unless the
#' text says `a single`, `tibble`/`data frame`). The documentation text becomes the schema
#' description verbatim.
#' @keywords internal
arg_schema <- function(name, default, doc) {
  required <- is.symbol(default) && !nzchar(as.character(default))
  schema <- list(description = if (nzchar(doc)) doc else paste("Argument", name))
  doc_l <- tolower(doc)

  if (!required && is.call(default) && identical(default[[1]], as.name("c")) &&
      all(vapply(as.list(default)[-1], is.character, logical(1)))) {
    vals <- vapply(as.list(default)[-1], identity, character(1))
    schema$type <- "string"
    schema$enum <- as.list(vals)
    schema$default <- vals[1]
    return(list(schema = schema, required = FALSE, kind = "enum"))
  }
  if (!required && is.logical(default) && length(default) == 1L) {
    schema$type <- "boolean"; schema$default <- default
    return(list(schema = schema, required = FALSE, kind = "scalar"))
  }
  if (!required && is.numeric(default) && length(default) == 1L) {
    schema$type <- if (grepl("integer", doc_l) || is.integer(default)) "integer" else "number"
    schema$default <- unname(default)
    return(list(schema = schema, required = FALSE, kind = "scalar"))
  }
  if (!required && is.character(default) && length(default) == 1L) {
    schema$type <- "string"; schema$default <- default
    return(list(schema = schema, required = FALSE, kind = "scalar"))
  }

  kind <- "scalar"
  is_single <- grepl("\\ba single\\b", doc_l)
  is_frame <- grepl("tibble|data frame|data\\.frame", doc_l)
  is_vec <- !is_single && grepl("character vector|vector of", doc_l)
  if (is_frame && is_vec) {
    schema$anyOf <- list(
      list(type = "array", items = list(type = "string")),
      list(type = "array", items = list(type = "object"))
    )
    kind <- "vector_or_frame"
  } else if (is_frame) {
    schema$type <- "array"; schema$items <- list(type = "object"); kind <- "frame"
  } else if (is_vec) {
    schema$type <- "array"; schema$items <- list(type = "string"); kind <- "vector"
  } else if (grepl("^integer|\\binteger\\b", doc_l)) {
    schema$type <- "integer"
  } else if (grepl("^logical|\\blogical\\b", doc_l)) {
    schema$type <- "boolean"
  } else if (grepl("date|posixct|iso 8601|timestamp|instant", doc_l)) {
    schema$type <- "string"
    schema$description <- paste(schema$description,
                                "Supply an ISO 8601 date (YYYY-MM-DD) or date-time (YYYY-MM-DDTHH:MM:SSZ).")
  } else {
    schema$type <- "string"
  }
  if (!required && !is.null(default) && !is.call(default) && !is.symbol(default) &&
      length(default) == 1L && !is.na(default)) {
    schema$default <- default
  }
  list(schema = schema, required = required, kind = kind)
}

#' Schema of the server-side shaping arguments
#' @keywords internal
shaping_schema <- function() {
  list(
    .limit = list(type = "integer", minimum = 1L, default = 200L,
                  description = "Maximum number of rows to return from the result."),
    .offset = list(type = "integer", minimum = 0L, default = 0L,
                   description = "Number of rows to skip before returning."),
    .columns = list(type = "array", items = list(type = "string"),
                    description = "Columns to keep (tidybrreg's English column names). Default: all."),
    .format = list(type = "string", enum = list("records", "csv", "markdown"), default = "records",
                   description = "Text rendering of the rows in the content block.")
  )
}

#' Schema of the structured result every tool returns
#' @keywords internal
output_schema <- function() {
  list(
    type = "object",
    properties = list(
      tool = list(type = "string"),
      kind = list(type = "string", enum = list("table", "vector", "scalar", "value"),
                  description = "table for tibbles, vector/scalar for atomic results, value otherwise."),
      rows = list(type = "array", items = list(type = "object"),
                  description = "The returned slice of rows, one JSON object per row."),
      value = list(description = "The result when it is not a table."),
      n_rows = list(type = "integer", description = "Rows in this slice."),
      n_total = list(type = "integer", description = "Rows in the full result."),
      offset = list(type = "integer"),
      columns = list(type = "array", items = list(type = "object",
        properties = list(name = list(type = "string"), type = list(type = "string")))),
      attributes = list(type = "object",
        description = "Metadata tidybrreg attached to the result (total_matches, complete, http_status, cursor, ...)."),
      conditions = list(type = "array", items = list(type = "object",
        properties = list(class = list(type = "string"), message = list(type = "string"),
                          fields = list(type = "object"))),
        description = "Warnings and messages tidybrreg signalled while producing the result.")
    ),
    required = list("tool", "kind", "n_total", "conditions")
  )
}

#' Tool definitions as sent to clients (without the function objects)
#' @keywords internal
tools_public <- function(tools) {
  unname(lapply(tools, function(t) t[c("name", "title", "description", "inputSchema",
                                        "outputSchema", "annotations")]))
}
