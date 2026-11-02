#' Call a tool with JSON arguments and shape the result
#'
#' Converts the JSON-RPC arguments to R values according to the inferred
#' argument kinds, calls the tidybrreg function, captures every warning
#' and message it signals (with condition classes and fields), and
#' returns the MCP `tools/call` result. Errors become `isError = TRUE`
#' results carrying the tidybrreg condition class and fields, never a
#' JSON-RPC protocol error.
#'
#' @param tool A tool definition from [mcp_tools()].
#' @param args Named list of arguments as decoded from JSON.
#' @returns A list with `content`, `structuredContent`, `isError`.
#' @keywords internal
call_tool <- function(tool, args) {
  args <- args %||% list()
  if (!is.list(args) || (length(args) > 0 && is.null(names(args)))) {
    return(tool_error("Arguments must be a JSON object.", class = "invalid_params"))
  }
  shaping <- list(
    limit = as.integer(args$.limit %||% 200L),
    offset = as.integer(args$.offset %||% 0L),
    columns = if (!is.null(args$.columns)) as.character(unlist(args$.columns)) else NULL,
    format = as.character(args$.format %||% "records")
  )
  max_rows <- getOption("tidybrregmcp.max_rows", 5000L)
  shaping$limit <- max(1L, min(shaping$limit, as.integer(max_rows)))
  shaping$offset <- max(0L, shaping$offset)
  if (!shaping$format %in% c("records", "csv", "markdown")) shaping$format <- "records"

  r_args <- args[!grepl("^\\.", names(args))]
  unknown <- setdiff(names(r_args), names(tool$arg_info))
  if (length(unknown) > 0) {
    return(tool_error(paste0("Unknown argument(s): ", paste(unknown, collapse = ", "),
                             ". Known: ", paste(names(tool$arg_info), collapse = ", ")),
                      class = "invalid_params"))
  }
  r_args <- convert_args(r_args, tool$arg_info)

  conditions <- list()
  record <- function(cnd, kind) {
    cls <- class(cnd)
    fields <- cnd[setdiff(names(cnd), c("message", "call", "trace", "parent", "body",
                                        "use_cli_format", "rlang"))]
    fields <- fields[vapply(fields, function(f) is.atomic(f) && length(f) <= 50L, logical(1))]
    conditions[[length(conditions) + 1L]] <<- list(
      kind = kind,
      class = cls[1],
      classes = cls,
      message = conditionMessage(cnd),
      fields = lapply(fields, json_ready)
    )
  }
  result <- tryCatch(
    withCallingHandlers(
      do.call(tool$fn, r_args),
      warning = function(w) { record(w, "warning"); invokeRestart("muffleWarning") },
      message = function(m) { record(m, "message"); invokeRestart("muffleMessage") }
    ),
    error = function(e) e
  )
  if (inherits(result, "error")) {
    return(tool_error(conditionMessage(result), class = class(result)[1],
                      classes = class(result), fields = condition_fields(result),
                      conditions = conditions))
  }
  shape_result(tool$name, result, shaping, conditions)
}

#' Fields of a condition that are JSON-safe
#' @keywords internal
condition_fields <- function(cnd) {
  fields <- cnd[setdiff(names(cnd), c("message", "call", "trace", "parent", "body",
                                      "use_cli_format", "rlang"))]
  fields <- fields[vapply(fields, function(f) (is.atomic(f) || is.list(f)) && length(f) <= 50L, logical(1))]
  lapply(fields, json_ready)
}

#' Build an error result for `tools/call`
#' @keywords internal
tool_error <- function(message, class = "error", classes = class, fields = list(),
                       conditions = list()) {
  structured <- list(
    error = list(class = class, classes = as.list(classes), message = message,
                 fields = fields),
    conditions = conditions
  )
  list(
    content = list(list(type = "text",
                        text = paste0("Error (", class, "): ", message))),
    structuredContent = structured,
    isError = TRUE
  )
}

#' Convert decoded JSON arguments to the R values tidybrreg expects
#' @keywords internal
convert_args <- function(args, arg_info) {
  for (nm in names(args)) {
    v <- args[[nm]]
    kind <- arg_info[[nm]]$kind %||% "scalar"
    if (is.null(v)) { args[nm] <- list(NULL); next }
    args[[nm]] <- switch(kind,
      frame = records_to_tibble(v),
      vector_or_frame = if (is.list(v) && length(v) > 0 && is.list(v[[1]])) records_to_tibble(v) else as.character(unlist(v)),
      vector = as.character(unlist(v)),
      enum = as.character(unlist(v))[1],
      if (is.list(v)) unlist(v) else v
    )
  }
  args
}

#' Rows of JSON objects to a tibble
#' @keywords internal
records_to_tibble <- function(rows) {
  if (length(rows) == 0) return(tibble::tibble())
  json <- jsonlite::toJSON(rows, auto_unbox = TRUE, null = "null")
  tibble::as_tibble(jsonlite::fromJSON(json, simplifyVector = TRUE))
}

#' Make an R value safe for `jsonlite::toJSON`
#' @keywords internal
json_ready <- function(x) {
  if (inherits(x, "POSIXt")) return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  if (inherits(x, "Date")) return(format(x, "%Y-%m-%d"))
  if (is.data.frame(x)) return(list(n_rows = nrow(x)))
  if (is.list(x)) return(lapply(x, json_ready))
  x
}

#' Shape a tidybrreg result into the MCP result
#' @keywords internal
shape_result <- function(name, result, shaping, conditions) {
  attrs <- attributes(result)
  attrs <- attrs[setdiff(names(attrs), c("names", "row.names", "class", "dim", "dimnames",
                                         "brreg_panel_meta", "tzone", "levels"))]
  attrs <- lapply(attrs, json_ready)

  if (is.data.frame(result)) {
    n_total <- nrow(result)
    cols <- if (!is.null(shaping$columns)) intersect(shaping$columns, names(result)) else names(result)
    slice <- result[cols]
    idx <- seq_len(n_total)
    idx <- idx[idx > shaping$offset]
    idx <- idx[seq_len(min(length(idx), shaping$limit))]
    slice <- slice[idx, , drop = FALSE]
    col_types <- lapply(names(slice), function(cn) list(name = cn, type = class(slice[[cn]])[1]))
    structured <- list(
      tool = name, kind = "table",
      rows = rows_json(slice),
      n_rows = nrow(slice), n_total = n_total, offset = shaping$offset,
      columns = col_types, attributes = attrs, conditions = conditions
    )
    text <- render_rows(slice, shaping$format, n_total, shaping$offset, attrs, conditions)
  } else {
    value <- unclass_simple(result)
    kind <- if (is.atomic(result) && length(result) == 1L) "scalar"
            else if (is.atomic(result)) "vector" else "value"
    structured <- list(
      tool = name, kind = kind, value = json_ready(value),
      n_total = length(result), attributes = attrs, conditions = conditions
    )
    text <- as.character(jsonlite::toJSON(json_ready(value), auto_unbox = TRUE, null = "null",
                                          na = "null", pretty = TRUE))
    if (length(conditions) > 0) text <- paste0(text, "\n\n", render_conditions(conditions))
  }
  list(
    content = list(list(type = "text", text = text)),
    structuredContent = structured,
    isError = FALSE
  )
}

#' @keywords internal
unclass_simple <- function(x) {
  if (inherits(x, "Date") || inherits(x, "POSIXt")) return(json_ready(x))
  if (is.factor(x)) return(as.character(x))
  x
}

#' Rows of a tibble as a list of JSON-ready objects
#' @keywords internal
rows_json <- function(df) {
  if (nrow(df) == 0) return(list())
  json <- jsonlite::toJSON(df, dataframe = "rows", POSIXt = "ISO8601", Date = "ISO8601",
                           na = "null", null = "null", auto_unbox = TRUE, digits = NA)
  jsonlite::fromJSON(json, simplifyVector = FALSE)
}

#' Text rendering of a slice of rows
#' @keywords internal
render_rows <- function(df, format, n_total, offset, attrs, conditions) {
  header <- sprintf("%d of %d row%s (offset %d), %d column%s.",
                    nrow(df), n_total, if (n_total == 1) "" else "s", offset,
                    ncol(df), if (ncol(df) == 1) "" else "s")
  body <- switch(format,
    csv = {
      con <- textConnection("csv_out", "w", local = TRUE)
      utils::write.csv(as.data.frame(lapply(df, format_cell)), con, row.names = FALSE)
      close(con)
      paste(csv_out, collapse = "\n")
    },
    markdown = md_table(df),
    as.character(jsonlite::toJSON(df, dataframe = "rows", POSIXt = "ISO8601",
                                  Date = "ISO8601", na = "null", null = "null",
                                  auto_unbox = TRUE, digits = NA, pretty = TRUE))
  )
  parts <- c(header, body)
  if (length(attrs) > 0) {
    parts <- c(parts, paste0("Attributes: ",
      as.character(jsonlite::toJSON(attrs, auto_unbox = TRUE, null = "null", na = "null"))))
  }
  if (length(conditions) > 0) parts <- c(parts, render_conditions(conditions))
  paste(parts, collapse = "\n\n")
}

#' @keywords internal
format_cell <- function(x) {
  if (is.list(x)) return(vapply(x, function(v) as.character(jsonlite::toJSON(v, auto_unbox = TRUE)), character(1)))
  if (inherits(x, "POSIXt")) return(format(x, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"))
  as.character(x)
}

#' @keywords internal
md_table <- function(df) {
  if (nrow(df) == 0) return("(no rows)")
  cells <- lapply(df, function(col) { v <- format_cell(col); v[is.na(v)] <- ""; gsub("|", "\\|", v, fixed = TRUE) })
  header <- paste0("| ", paste(names(df), collapse = " | "), " |")
  sep <- paste0("|", paste(rep(" --- |", ncol(df)), collapse = ""))
  rows <- vapply(seq_len(nrow(df)), function(i) {
    paste0("| ", paste(vapply(cells, function(c) c[i], character(1)), collapse = " | "), " |")
  }, character(1))
  paste(c(header, sep, rows), collapse = "\n")
}

#' @keywords internal
render_conditions <- function(conditions) {
  lines <- vapply(conditions, function(c) {
    paste0("- [", c$kind, " ", c$class, "] ", gsub("\n", " ", c$message))
  }, character(1))
  paste0("Conditions signalled by tidybrreg:\n", paste(lines, collapse = "\n"))
}
