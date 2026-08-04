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

#' Rename fields using field_dict; pass through unmapped fields
#' All dict columns appear in output; absent fields become typed NA.
#' @keywords internal
rename_from_dict <- function(flat) {
  dict <- field_dict
  result <- list()
  mapped_api_paths <- character()

  for (i in seq_len(nrow(dict))) {
    api_path <- dict$api_path[i]
    col_name <- dict$col_name[i]
    if (api_path %in% names(flat)) {
      result[[col_name]] <- flat[[api_path]]
      mapped_api_paths <- c(mapped_api_paths, api_path)
    }
  }

  unmapped <- setdiff(names(flat), mapped_api_paths)
  unmapped <- unmapped[!grepl("^_links", unmapped)]
  for (api_path in unmapped) {
    col_name <- to_snake(api_path)
    if (!col_name %in% names(result)) {
      result[[col_name]] <- flat[[api_path]]
    }
  }

  result <- lapply(result, function(v) {
    if (is.null(v) || length(v) == 0) return(NA)
    if (length(v) > 1) return(collapse_observed(v))
    v
  })
  tibble::as_tibble(result)
}

#' Coerce columns to declared types from field_dict
#' @keywords internal
coerce_types <- function(tbl) {
  dict <- field_dict
  for (i in seq_len(nrow(dict))) {
    col <- dict$col_name[i]
    if (!col %in% names(tbl)) next
    target <- dict$type[i]
    tbl[[col]] <- switch(target,
      Date      = as.Date(as.character(tbl[[col]])),
      integer   = as.integer(tbl[[col]]),
      numeric   = as.numeric(tbl[[col]]),
      logical   = as.logical(tbl[[col]]),
      character = as.character(tbl[[col]]),
      tbl[[col]]
    )
  }
  tbl
}

#' Parse a list of raw entities into a combined tibble
#' @keywords internal
parse_entities <- function(raw_list) {
  dplyr::bind_rows(lapply(raw_list, parse_entity))
}
