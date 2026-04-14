#' Flatten a single brreg entity JSON to a 1-row tibble
#'
#' Uses the field_dict column dictionary. Fields present in the API response
#' but absent from field_dict pass through with auto-generated snake_case names.
#' Fields in field_dict but absent from the response become NA with correct type.
#' @keywords internal
parse_entity <- function(raw) {
  flat <- flatten_json(raw)
  mapped <- rename_from_dict(flat)
  coerce_types(mapped)
}

#' Recursively flatten nested JSON into dot-notation keys
#' @keywords internal
flatten_json <- function(x, prefix = "") {
  out <- list()
  for (nm in names(x)) {
    full <- if (nzchar(prefix)) paste0(prefix, ".", nm) else nm
    val <- x[[nm]]
    if (is.list(val) && !is.null(names(val))) {
      out <- c(out, flatten_json(val, full))
    } else if (is.list(val) && is.null(names(val))) {
      out[[full]] <- paste(unlist(val), collapse = ", ")
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

  na_for_type <- function(type) {
    switch(type,
      character = NA_character_,
      Date      = as.Date(NA),
      integer   = NA_integer_,
      numeric   = NA_real_,
      logical   = NA,
      NA
    )
  }

  for (i in seq_len(nrow(dict))) {
    api_path <- dict$api_path[i]
    col_name <- dict$col_name[i]
    if (api_path %in% names(flat)) {
      result[[col_name]] <- flat[[api_path]]
      mapped_api_paths <- c(mapped_api_paths, api_path)
    } else {
      result[[col_name]] <- na_for_type(dict$type[i])
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
    if (length(v) > 1) return(paste(v, collapse = "; "))
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
