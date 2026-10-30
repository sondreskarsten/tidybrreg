#' Write the tidybrreg MCP manifest
#'
#' Serialises everything a server needs to expose tidybrreg over the
#' Model Context Protocol without running R: the tool catalogue of
#' [mcp_tools()] (titles, descriptions, input and output schemas), the
#' machine-readable endpoint contract shipped by tidybrreg
#' (`inst/extdata/endpoints.json`, tested against the functions), the
#' bundled dictionaries with their vintages, every help topic as
#' Markdown, and the server instructions. The output is deterministic
#' for a given installed tidybrreg (no timestamps), so the Node
#' implementation in `tidybrreg-mcp-node/` commits it and CI fails when
#' regenerating it changes anything: the non-R server changes exactly
#' when tidybrreg does.
#'
#' @param path File to write. `NULL` returns the manifest as a list
#'   without writing.
#' @inheritParams mcp_tools
#' @returns The manifest as a list, invisibly when `path` is given.
#' @export
#' @examples
#' m <- mcp_manifest(NULL)
#' names(m)
#' length(m$tools)
mcp_manifest <- function(path = "tidybrreg-mcp-manifest.json",
                         package = "tidybrreg", exclude = character()) {
  tools <- mcp_tools(package, exclude = exclude)
  desc <- utils::packageDescription(package)
  endpoints_file <- system.file("extdata", "endpoints.json", package = package)
  if (!nzchar(endpoints_file)) {
    cli::cli_abort("{.pkg {package}} ships no {.file inst/extdata/endpoints.json}.")
  }
  endpoints <- jsonlite::fromJSON(endpoints_file, simplifyVector = FALSE)

  db <- tools::Rd_db(package)
  docs <- list()
  for (nm in names(db)) {
    topic <- sub("\\.Rd$", "", nm)
    docs[[topic]] <- rd_topic_md(db[[nm]], topic)
  }

  dic <- function(name) {
    x <- getExportedValue(package, name)
    as.data.frame(x, stringsAsFactors = FALSE)
  }
  bundled <- function(name) {
    x <- get(name, envir = asNamespace(package))
    list(vintage = format(attr(x, "vintage")),
         classification_id = attr(x, "classification_id"),
         source_url = attr(x, "source_url"),
         rows = as.data.frame(x, stringsAsFactors = FALSE))
  }

  manifest <- list(
    manifest_version = 1L,
    tidybrreg = list(
      version = as.character(desc$Version),
      title = desc$Title,
      description = gsub("\\s+", " ", desc$Description),
      license = desc$License,
      url = desc$URL
    ),
    protocol = list(version = mcp_protocol_version(), server_name = "tidybrreg-mcp"),
    instructions = server_instructions(package),
    tools = lapply(unname(tools), function(t) {
      c(t[c("name", "title", "description", "inputSchema", "outputSchema", "annotations")],
        list(args = lapply(t$arg_info, function(a) list(kind = a$kind, required = isTRUE(a$required)))))
    }),
    shaping = shaping_schema(),
    endpoints = endpoints,
    dictionaries = list(
      field_dict = dic("field_dict"),
      legal_forms = dic("legal_forms"),
      role_types = dic("role_types"),
      role_groups = dic("role_groups"),
      regnskap_dict = dic("regnskap_dict"),
      regnskap_groups = dic("regnskap_groups"),
      regnskap_items = dic("regnskap_items"),
      nace_codes = bundled("nace_codes"),
      sector_codes = bundled("sector_codes")
    ),
    docs = docs
  )
  if (is.null(path)) return(manifest)
  jsonlite::write_json(manifest, path, auto_unbox = TRUE, pretty = TRUE, null = "null",
                       na = "null", digits = NA)
  invisible(manifest)
}
