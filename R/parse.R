#' Flatten a single brreg entity JSON to a 1-row tibble
#'
#' Uses the field_dict column dictionary. Fields present in the API response
#' but absent from field_dict pass through with auto-generated snake_case names.
#' Fields in field_dict but absent from the response are omitted rather than
#' materialized as NA: a column the register did not emit is not asserted.
#' Multi-entity callers bind the per-entity tibbles, so a column appears
#' whenever any entity in the batch carried it, NA for the rest.
#' @keywords internal
parse_entity <- function(raw) {
  flat <- flatten_json(raw)
  mapped <- rename_from_dict(flat)
  coerce_types(mapped)
}

#' Collapse an observed array value to a single character cell
#'
#' BRREG returns addresses, `vedtektsfestetFormaal`, and `aktivitet`
#' as arrays of register line-fragments. Element text routinely
#' contains commas and semicolons but never newlines, so `"\n"` is the
#' only separator that survives a round trip: a consumer can split it
#' back into the observed elements, which `"; "` and `", "` do not
#' allow. Arrays whose elements are objects (`historiskeNavn`,
#' `paategninger`) have no meaningful text join and are serialized to
#' JSON instead, preserving field structure.
#'
#' Note that the CSV bulk is BRREG's own flattening and uses
#' field-specific separators (newline for addresses, space for
#' wrapped text such as `vedtektsfestetFormaal`), so CSV-sourced and
#' JSON-sourced values for those fields are not byte-identical and
#' cannot be made so without imposing a per-field rule.
#'
#' @param val A list or atomic vector taken from a parsed response.
#' @returns A length-1 character value.
#' @keywords internal
collapse_observed <- function(val) {
  if (is.null(val) || length(val) == 0) return(NA_character_)
  if (is.data.frame(val)) {
    if (nrow(val) == 0) return(NA_character_)
    return(as.character(jsonlite::toJSON(val, auto_unbox = TRUE)))
  }
  if (is.list(val) && all(vapply(val, is.null, logical(1)))) {
    return(NA_character_)
  }
  if (is.list(val) &&
      any(vapply(val, function(e) is.list(e) || is.data.frame(e), logical(1)))) {
    return(as.character(jsonlite::toJSON(val, auto_unbox = TRUE)))
  }
  paste(as.character(unlist(val)), collapse = "\n")
}


#' Recursively flatten nested JSON into dot-notation keys
#'
#' Nested objects recurse into `parent.child` keys. Arrays are
#' collapsed by [collapse_observed()].
#' @param x A parsed JSON list.
#' @param prefix Key prefix used during recursion.
#' @returns A flat named list.
#' @keywords internal
flatten_json <- function(x, prefix = "") {
  out <- list()
  for (nm in names(x)) {
    full <- if (nzchar(prefix)) paste0(prefix, ".", nm) else nm
    val <- x[[nm]]
    if (is.list(val) && !is.null(names(val))) {
      out <- c(out, flatten_json(val, full))
    } else if (is.list(val) && is.null(names(val))) {
      out[[full]] <- collapse_observed(val)
    } else {
      out[[full]] <- val
    }
  }
  out
}

#' Is a dot-notation path part of a HAL `_links` block?
#'
#' HAL hypermedia links (`_links.self.href`,
#' `organisasjonsform._links.self.href`, or `links` after
#' `jsonlite::fromJSON(flatten = TRUE)` strips the underscore) describe
#' API navigation, not the entity, and are removed wherever they occur
#' in the path, not only at the top level.
#' @param path Character vector of dot-notation paths.
#' @returns Logical vector.
#' @keywords internal
is_hal_link_path <- function(path) {
  vapply(strsplit(path, ".", fixed = TRUE), function(parts) {
    any(parts %in% c("_links", "links"))
  }, logical(1))
}

#' Rename fields using field_dict; pass through unmapped fields
#'
#' Only observed fields are emitted. A dictionary target that two
#' distinct observed paths map to (the dictionary carries both the JSON
#' and CSV spellings of a few fields) is filled from the first path in
#' dictionary order; the second path falls back to its auto-generated
#' snake_case name, keeping its dictionary type, so no observed value is
#' lost. Unmapped paths whose snake_case names collide are made unique
#' with a numeric suffix.
#' @param flat A flat named list from [flatten_json()].
#' @param dict The field map to apply: [field_dict] (default) or
#'   `regnskap_dict`.
#' @keywords internal
rename_from_dict <- function(flat, dict = field_dict) {
  flat <- flat[!is_hal_link_path(names(flat))]
  result <- list()
  mapped_api_paths <- character()

  for (i in seq_len(nrow(dict))) {
    api_path <- dict$api_path[i]
    col_name <- dict$col_name[i]
    if (!api_path %in% names(flat)) next
    if (col_name %in% names(result)) next
    result[[col_name]] <- flat[[api_path]]
    mapped_api_paths <- c(mapped_api_paths, api_path)
  }

  unmapped <- setdiff(names(flat), mapped_api_paths)
  dict_types <- character()
  if (length(unmapped) > 0) {
    snake <- make.unique(c(names(result), to_snake(unmapped)), sep = "_")
    snake <- snake[-seq_along(result)]
    for (j in seq_along(unmapped)) {
      result[[snake[j]]] <- flat[[unmapped[j]]]
      idx <- match(unmapped[j], dict$api_path)
      if (!is.na(idx)) dict_types[snake[j]] <- dict$type[idx]
    }
  }

  result <- lapply(result, function(v) {
    if (is.null(v) || length(v) == 0) return(NA)
    if (length(v) > 1) return(collapse_observed(v))
    v
  })
  out <- tibble::as_tibble(result)
  if (length(dict_types) > 0) attr(out, "brreg_dict_types") <- dict_types
  out
}

#' Coerce one column to a dictionary type, reporting failures
#'
#' The single coercion rule shared by the live JSON path
#' ([coerce_types()]) and the bulk path ([rename_and_coerce()]), so a
#' dictionary type is invariant across sources. A value that is present
#' (not `NA`, not empty) but does not parse is a failure; its index is
#' returned so the caller can build the `brreg_parse_problems` table.
#'
#' @param x A vector.
#' @param type One of the [field_dict] types.
#' @returns A list with `value` (the coerced vector) and `failed`
#'   (integer indices of unparseable values).
#' @keywords internal
coerce_column <- function(x, type) {
  present <- !is.na(x) & !(is.character(x) & !nzchar(trimws(as.character(x))))
  value <- switch(type,
    Date      = parse_brreg_date(x),
    integer   = suppressWarnings(as.integer(as.character(x))),
    numeric   = suppressWarnings(as.numeric(as.character(x))),
    logical   = parse_brreg_logical(x),
    character = as.character(x),
    x
  )
  failed <- which(present & is.na(value))
  list(value = value, failed = failed)
}

#' Parse BRREG boolean renderings
#' @keywords internal
parse_brreg_logical <- function(x) {
  if (is.logical(x)) return(x)
  s <- tolower(trimws(as.character(x)))
  out <- rep(NA, length(s))
  out[s %in% c("true", "t", "ja", "1")] <- TRUE
  out[s %in% c("false", "f", "nei", "0")] <- FALSE
  out
}

#' Coerce columns to declared types from field_dict
#'
#' Applied to every dictionary column present in `tbl`. Failures are
#' attached as the `brreg_parse_problems` attribute and signalled once
#' as a `tidybrreg_warning_parse`.
#' @param tbl A tibble from [rename_from_dict()].
#' @param dict The field map whose types apply: [field_dict] (default)
#'   or `regnskap_dict`.
#' @keywords internal
coerce_types <- function(tbl, dict = field_dict) {
  dict <- dict[!duplicated(dict$col_name), ]
  types <- stats::setNames(dict$type, dict$col_name)
  extra <- attr(tbl, "brreg_dict_types")
  attr(tbl, "brreg_dict_types") <- NULL
  types <- c(types, extra)
  types <- types[names(types) %in% names(tbl)]
  problems <- list()
  for (col in names(types)) {
    coerced <- coerce_column(tbl[[col]], types[[col]])
    if (length(coerced$failed) > 0) {
      problems[[col]] <- parse_problem_rows(col, types[[col]], tbl[[col]], coerced$failed)
    }
    tbl[[col]] <- coerced$value
  }
  attach_parse_problems(tbl, problems)
}

#' Build the rows of a parse-problem table for one column
#'
#' At most `max_rows` failures are listed, taken from the same indices
#' for `row` and `actual` so the two columns always agree; `n_failed`
#' carries the total count.
#' @keywords internal
parse_problem_rows <- function(col, type, original, failed, max_rows = 20L) {
  shown <- failed[seq_len(min(length(failed), max_rows))]
  tibble::tibble(
    column   = col,
    row      = shown,
    expected = type,
    actual   = as.character(original[shown]),
    n_failed = length(failed)
  )
}

#' Attach the parse-problem attribute and warn once
#' @keywords internal
attach_parse_problems <- function(tbl, problems) {
  if (length(problems) == 0) return(tbl)
  prob_tbl <- dplyr::bind_rows(problems)
  attr(tbl, "brreg_parse_problems") <- prob_tbl
  n <- sum(vapply(problems, function(p) p$n_failed[1], integer(1)))
  brreg_warn(c(
    "{n} parse failure{?s} in {length(problems)} column{?s}.",
    "i" = "Use {.code attr(result, \"brreg_parse_problems\")} to inspect."
  ), class = "parse", n = n)
  tbl
}

#' Parse a list of raw entities into a combined tibble
#' @keywords internal
parse_entities <- function(raw_list) {
  dplyr::bind_rows(lapply(raw_list, parse_entity))
}

#' Typed zero-row tibble for entity results
#'
#' The columns an empty search or lookup result carries. Entity
#' emission is batch-scoped, so an empty batch has observed nothing;
#' the identifying columns are still present, typed, so downstream code
#' can select them.
#' @keywords internal
empty_entities <- function() {
  tibble::tibble(org_nr = character(), name = character(),
                 legal_form = character())
}
