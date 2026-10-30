withr::local_options(list(tidybrreg.offline = TRUE), .local_envir = teardown_env())

srv <- mcp_server()

req <- function(method, params = NULL, id = 1L) {
  m <- list(jsonrpc = "2.0", id = id, method = method)
  if (!is.null(params)) m$params <- params
  m
}

test_that("every tidybrreg export is a tool and nothing else is", {
  expect_setequal(names(srv$tools), getNamespaceExports("tidybrreg"))
  expect_length(srv$tools, 16L)
  for (t in srv$tools) {
    expect_true(nzchar(t$title))
    expect_true(nzchar(t$description))
    expect_equal(t$inputSchema$type, "object")
    expect_true(all(names(formals(t$fn)) %in% names(t$inputSchema$properties)))
    expect_true(all(c(".limit", ".offset", ".columns", ".format") %in% names(t$inputSchema$properties)))
  }
})

test_that("the MCP package version moves in tandem with tidybrreg", {
  expect_equal(utils::packageVersion("tidybrregmcp"),
               utils::packageVersion("tidybrreg"))
})

test_that("schemas follow the formals and the documented types", {
  e <- srv$tools$brreg_entity$inputSchema
  expect_equal(unlist(e$required), "org_nr")
  expect_equal(unlist(e$properties$registry$enum), c("auto", "enheter", "underenheter"))
  expect_equal(e$properties$registry$default, "auto")
  expect_equal(e$properties$org_nr$type, "string")
  s <- srv$tools$brreg_search$inputSchema
  expect_null(s$required)
  expect_equal(s$properties$max_results$type, "integer")
  expect_equal(s$properties$max_results$default, 200)
  expect_equal(s$properties$bankrupt$type, "boolean")
  u <- srv$tools$brreg_updates$inputSchema
  expect_equal(u$properties$since$type, "string")
  expect_match(u$properties$since$description, "ISO 8601")
  expect_equal(u$properties$include_changes$type, "boolean")
  expect_equal(u$properties$include_changes$default, FALSE)
  l <- srv$tools$brreg_label$inputSchema
  expect_length(l$properties$x$anyOf, 2L)
  d <- srv$tools$brreg_download$inputSchema
  expect_equal(unlist(d$properties$type_output$enum), c("tibble", "path"))
  expect_match(srv$tools$brreg_roles$description, "Status handling")
})

test_that("descriptions are rendered from the help pages", {
  expect_match(srv$tools$brreg_entity$description, "Observed fields only")
  expect_match(srv$tools$brreg_entity$inputSchema$properties$org_nr$description, "9-digit")
  expect_false(grepl("\\\\code", srv$tools$brreg_entity$description))
  expect_false(grepl("\\\\link", srv$tools$brreg_search$description))
})

test_that("initialize negotiates and carries tidybrreg's working rules", {
  r <- mcp_handle(srv, req("initialize", list(protocolVersion = "2025-03-26",
                                                capabilities = list(), clientInfo = list(name = "t"))))
  expect_equal(r$result$protocolVersion, "2025-03-26")
  expect_equal(r$result$serverInfo$name, "tidybrreg-mcp")
  expect_match(r$result$instructions, "Coded values are returned as codes")
  expect_match(r$result$instructions, "tidybrreg_error_result_window")
  expect_null(mcp_handle(srv, list(jsonrpc = "2.0", method = "notifications/initialized")))
  r <- mcp_handle(srv, req("initialize", list(protocolVersion = "1999-01-01")))
  expect_equal(r$result$protocolVersion, "2025-06-18")
})

test_that("ping, tools/list and unknown methods behave per JSON-RPC", {
  r <- mcp_handle(srv, req("ping"))
  expect_equal(length(r$result), 0L)
  r <- mcp_handle(srv, req("tools/list"))
  expect_length(r$result$tools, 16L)
  expect_null(r$result$tools[[1]]$fn)
  expect_true(all(vapply(r$result$tools, function(t) !is.null(t$outputSchema), logical(1))))
  r <- mcp_handle(srv, req("nope"))
  expect_equal(r$error$code, -32601L)
  r <- mcp_handle(srv, req("tools/call", list(name = "nope")))
  expect_equal(r$error$code, -32602L)
  r <- mcp_handle(srv, list(jsonrpc = "2.0", id = 9L))
  expect_equal(r$error$code, -32600L)
})

test_that("tools/call runs tidybrreg and shapes vectors", {
  r <- mcp_handle(srv, req("tools/call", list(
    name = "brreg_validate", arguments = list(org_nr = list("923609016", "123")))))
  expect_false(r$result$isError)
  expect_equal(r$result$structuredContent$kind, "vector")
  expect_equal(r$result$structuredContent$value, c(TRUE, FALSE))
  expect_equal(r$result$structuredContent$tool, "brreg_validate")
  r <- mcp_handle(srv, req("tools/call", list(
    name = "brreg_label", arguments = list(x = list("AS", "ASA"), dic = "legal_form", lang = "no"))))
  expect_equal(r$result$structuredContent$value, c("Aksjeselskap", "Allmennaksjeselskap"))
})

test_that("tools/call shapes tables with limit, offset, columns and attributes", {
  r <- mcp_handle(srv, req("tools/call", list(
    name = "get_brreg_dic", arguments = list(dictname = "nace", .limit = 3L, .offset = 1L,
                                             .columns = list("code", "name")))))
  sc <- r$result$structuredContent
  expect_equal(sc$kind, "table")
  expect_equal(sc$n_rows, 3L)
  expect_true(sc$n_total > 1000L)
  expect_equal(sc$offset, 1L)
  expect_equal(vapply(sc$columns, function(c) c$name, character(1)), c("code", "name"))
  expect_equal(sc$attributes$source, "bundled")
  expect_equal(sc$attributes$vintage, "2026-06-16")
  expect_match(r$result$content[[1]]$text, "3 of")
  r <- mcp_handle(srv, req("tools/call", list(
    name = "get_brreg_dic", arguments = list(dictname = "sector", .format = "markdown", .limit = 2L))))
  expect_match(r$result$content[[1]]$text, "^2 of 33 rows")
  expect_match(r$result$content[[1]]$text, "\\| code \\| name \\| level \\|")
  r <- mcp_handle(srv, req("tools/call", list(
    name = "get_brreg_dic", arguments = list(dictname = "sector", .format = "csv", .limit = 2L))))
  expect_match(r$result$content[[1]]$text, "\"code\",\"name\",\"level\"")
})

test_that("tools/call reports tidybrreg errors with their condition class", {
  r <- mcp_handle(srv, req("tools/call", list(name = "brreg_entity", arguments = list(org_nr = "123"))))
  expect_true(r$result$isError)
  expect_equal(r$result$structuredContent$error$class, "tidybrreg_error_invalid_org_nr")
  expect_equal(r$result$structuredContent$error$fields$org_nr, "123")
  expect_match(r$result$content[[1]]$text, "Invalid organization number")
  r <- mcp_handle(srv, req("tools/call", list(name = "brreg_entity", arguments = list(foo = 1))))
  expect_true(r$result$isError)
  expect_match(r$result$structuredContent$error$message, "Unknown argument")
})

test_that("tools/call captures tidybrreg warnings as conditions", {
  withr::local_options(list(tidybrreg.offline = FALSE))
  testthat::local_mocked_bindings(fetch_klass = function(...) stop("no route"), .package = "tidybrreg")
  r <- mcp_handle(srv, req("tools/call", list(
    name = "get_brreg_dic", arguments = list(dictname = "nace", refresh = TRUE, .limit = 1L))))
  expect_false(r$result$isError)
  cls <- vapply(r$result$structuredContent$conditions, function(c) c$class, character(1))
  expect_true("tidybrreg_warning_bundled_fallback" %in% cls)
  expect_match(r$result$content[[1]]$text, "Conditions signalled")
})

test_that("resources expose help pages, datasets, news and provenance", {
  r <- mcp_handle(srv, req("resources/list"))
  uris <- vapply(r$result$resources, function(x) x$uri, character(1))
  expect_true(all(c("tidybrreg://docs/brreg_search", "tidybrreg://docs/tidybrreg_provenance",
                    "tidybrreg://data/field_dict", "tidybrreg://data/legal_forms") %in% uris))
  r <- mcp_handle(srv, req("resources/read", list(uri = "tidybrreg://docs/brreg_search")))
  txt <- r$result$contents[[1]]$text
  expect_match(txt, "^# brreg_search")
  expect_match(txt, "## Arguments")
  expect_match(txt, "Result window")
  r <- mcp_handle(srv, req("resources/read", list(uri = "tidybrreg://data/field_dict")))
  expect_match(r$result$contents[[1]]$mimeType, "json")
  expect_equal(nrow(jsonlite::fromJSON(r$result$contents[[1]]$text)), nrow(tidybrreg::field_dict))
  r <- mcp_handle(srv, req("resources/read", list(uri = "tidybrreg://nope")))
  expect_equal(r$error$code, -32002L)
})

test_that("exclusions drop tools from the catalogue", {
  withr::local_envvar(TIDYBRREG_MCP_EXCLUDE = "brreg_download, brreg_search")
  s2 <- mcp_server()
  expect_false(any(c("brreg_download", "brreg_search") %in% names(s2$tools)))
  expect_length(s2$tools, 14L)
})

test_that("the HTTP handler speaks streamable HTTP", {
  post <- function(body, auth = NULL, method = "POST", path = "/mcp") {
    raw <- charToRaw(body)
    req <- list(PATH_INFO = path, REQUEST_METHOD = method,
                rook.input = list(read = function() raw))
    if (!is.null(auth)) req$HTTP_AUTHORIZATION <- auth
    http_call(srv, req, token = "secret")
  }
  r <- post(encode_msg(req("ping")), auth = "Bearer secret")
  expect_equal(r$status, 200L)
  expect_equal(jsonlite::fromJSON(r$body)$id, 1L)
  expect_true(nzchar(r$headers[["Mcp-Session-Id"]]))
  expect_equal(post(encode_msg(req("ping")))$status, 401L)
  expect_equal(post("", method = "GET", auth = "Bearer secret")$status, 405L)
  expect_equal(post("", method = "DELETE", auth = "Bearer secret")$status, 200L)
  expect_equal(post("{not json", auth = "Bearer secret")$status, 200L)
  expect_equal(jsonlite::fromJSON(post("{not json", auth = "Bearer secret")$body)$error$code, -32700L)
  n <- post(encode_msg(list(jsonrpc = "2.0", method = "notifications/initialized")), auth = "Bearer secret")
  expect_equal(n$status, 202L)
  h <- http_call(srv, list(PATH_INFO = "/health", REQUEST_METHOD = "GET"))
  expect_equal(jsonlite::fromJSON(h$body)$tools, 16L)
  batch <- post(encode_msg(list(req("ping", id = 1L), req("ping", id = 2L))), auth = "Bearer secret")
  expect_equal(nrow(jsonlite::fromJSON(batch$body)), 2L)
})

test_that("the stdio transport answers line-delimited JSON-RPC", {
  skip_if_not_installed("callr")
  skip_if_not("tidybrregmcp" %in% rownames(utils::installed.packages()),
              "tidybrregmcp is not installed in the library")
  input <- withr::local_tempfile(fileext = ".jsonl")
  writeLines(c(encode_msg(req("initialize", list(protocolVersion = "2025-06-18"), id = 1L)),
               encode_msg(list(jsonrpc = "2.0", method = "notifications/initialized")),
               encode_msg(req("tools/call", list(name = "brreg_validate",
                                                arguments = list(org_nr = "923609016")), id = 2L))),
             input)
  out <- callr::rscript(
    withr::local_tempfile(fileext = ".R", lines = "options(tidybrreg.offline = TRUE); tidybrregmcp::mcp_serve('stdio')"),
    stdin = input, fail_on_status = FALSE
  )
  lines <- strsplit(out$stdout, "\n")[[1]]
  lines <- lines[nzchar(lines)]
  expect_length(lines, 2L)
  expect_equal(jsonlite::fromJSON(lines[2])$result$structuredContent$value, TRUE)
})

test_that("the manifest carries everything a non-R server needs", {
  m <- mcp_manifest(NULL)
  expect_equal(m$manifest_version, 1L)
  expect_equal(m$tidybrreg$version, as.character(utils::packageVersion("tidybrreg")))
  expect_length(m$tools, 16L)
  expect_setequal(vapply(m$tools, function(t) t$name, character(1)), getNamespaceExports("tidybrreg"))
  expect_setequal(names(m$endpoints$functions), getNamespaceExports("tidybrreg"))
  expect_equal(m$endpoints$services$enhetsregisteret, "https://data.brreg.no/enhetsregisteret/api")
  expect_equal(nrow(m$dictionaries$field_dict), nrow(tidybrreg::field_dict))
  expect_equal(m$dictionaries$nace_codes$vintage, "2026-06-16")
  expect_true(all(c("brreg_search", "tidybrreg_conditions", "tidybrreg_endpoints",
                    "tidybrreg_provenance") %in% names(m$docs)))
  expect_match(m$instructions, "Coded values")
  f <- withr::local_tempfile(fileext = ".json")
  mcp_manifest(f)
  back <- jsonlite::fromJSON(f, simplifyVector = FALSE)
  expect_equal(length(back$tools), 16L)
  expect_equal(back$tools[[1]]$inputSchema$type, "object")
  expect_true(is.list(back$endpoints$functions$brreg_search$query))
})
