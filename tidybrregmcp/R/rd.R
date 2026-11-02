#' Help pages of a package as parsed Rd objects
#'
#' Reads the installed Rd database of `package` and indexes it by every
#' alias, so a function name resolves to its help page.
#'
#' @param package Package name.
#' @returns A named list of Rd objects, one entry per alias.
#' @keywords internal
rd_index <- function(package = "tidybrreg") {
  db <- tools::Rd_db(package)
  out <- list()
  for (nm in names(db)) {
    rd <- db[[nm]]
    aliases <- unlist(lapply(rd_sections(rd, "\\alias"), rd_text))
    for (a in aliases) out[[a]] <- rd
  }
  out
}

#' Top-level sections of an Rd object with a given tag
#' @keywords internal
rd_sections <- function(rd, tag) {
  rd[vapply(rd, function(el) identical(attr(el, "Rd_tag"), tag), logical(1))]
}

#' First section of an Rd object with a given tag, or `NULL`
#' @keywords internal
rd_section <- function(rd, tag) {
  s <- rd_sections(rd, tag)
  if (length(s) == 0) NULL else s[[1]]
}

#' Plain text of an Rd fragment (no markup)
#' @keywords internal
rd_text <- function(x) {
  if (is.character(x)) return(paste(x, collapse = ""))
  paste(vapply(x, rd_text, character(1)), collapse = "")
}

#' Render an Rd fragment as Markdown
#'
#' Handles the markup roxygen2 emits for Markdown-authored
#' documentation: code and links, emphasis, itemised and described lists,
#' sections, tables, preformatted blocks, URLs. Unknown tags are rendered
#' through their children, so no documentation text is lost.
#'
#' @param x An Rd object or fragment.
#' @returns A single Markdown string.
#' @keywords internal
rd_md <- function(x) {
  if (is.null(x)) return("")
  tag <- attr(x, "Rd_tag") %||% ""
  if (is.character(x)) {
    if (tag == "COMMENT") return("")
    return(paste(x, collapse = ""))
  }
  kids <- function(el = x) paste(vapply(el, rd_md, character(1)), collapse = "")
  switch(tag,
    "\\code" = , "\\verb" = , "\\samp" = paste0("`", rd_text(x), "`"),
    "\\link" = kids(),
    "\\emph" = paste0("*", kids(), "*"),
    "\\strong" = , "\\bold" = paste0("**", kids(), "**"),
    "\\pkg" = kids(),
    "\\sQuote" = paste0("'", kids(), "'"),
    "\\dQuote" = paste0("\"", kids(), "\""),
    "\\url" = paste0("<", rd_text(x), ">"),
    "\\href" = paste0("[", rd_md(x[[2]]), "](", rd_text(x[[1]]), ")"),
    "\\email" = paste0("<", rd_text(x), ">"),
    "\\preformatted" = paste0("\n\n```\n", rd_text(x), "\n```\n\n"),
    "\\itemize" = rd_list(x, ordered = FALSE),
    "\\enumerate" = rd_list(x, ordered = TRUE),
    "\\describe" = rd_describe(x),
    "\\section" = , "\\subsection" = paste0("\n\n### ", trimws(rd_md(x[[1]])), "\n\n",
                                             trimws(rd_md(x[[2]])), "\n\n"),
    "\\tabular" = rd_tabular(x),
    "\\ifelse" = rd_md(x[[3]]),
    "\\if" = "",
    "\\out" = "",
    "\\eqn" = , "\\deqn" = paste0("$", rd_text(x[[1]]), "$"),
    "\\dots" = , "\\ldots" = "...",
    "\\R" = "R",
    "\\cr" = "\n",
    "\\tab" = " | ",
    "\\item" = "",
    "\\method" = , "\\S3method" = , "\\S4method" = paste0(rd_text(x[[1]]), ".", rd_text(x[[2]])),
    "\\dontrun" = , "\\donttest" = , "\\dontshow" = kids(),
    kids()
  )
}

#' Render an `\itemize` or `\enumerate` list
#' @keywords internal
rd_list <- function(x, ordered = FALSE) {
  items <- list()
  current <- NULL
  for (el in x) {
    if (identical(attr(el, "Rd_tag"), "\\item")) {
      if (!is.null(current)) items[[length(items) + 1L]] <- current
      current <- ""
    } else if (!is.null(current)) {
      current <- paste0(current, rd_md(el))
    }
  }
  if (!is.null(current)) items[[length(items) + 1L]] <- current
  items <- trimws(gsub("\\s+", " ", unlist(items)))
  items <- items[nzchar(items)]
  if (length(items) == 0) return("")
  marks <- if (ordered) paste0(seq_along(items), ". ") else rep("- ", length(items))
  paste0("\n\n", paste0(marks, items, collapse = "\n"), "\n\n")
}

#' Render a `\describe` list as a definition list
#' @keywords internal
rd_describe <- function(x) {
  items <- character()
  for (el in x) {
    if (identical(attr(el, "Rd_tag"), "\\item") && length(el) >= 2L) {
      items <- c(items, paste0("- **", trimws(rd_md(el[[1]])), "**: ",
                               trimws(gsub("\\s+", " ", rd_md(el[[2]])))))
    }
  }
  if (length(items) == 0) return("")
  paste0("\n\n", paste(items, collapse = "\n"), "\n\n")
}

#' Render a `\tabular` as a Markdown table
#' @keywords internal
rd_tabular <- function(x) {
  body <- x[[2]]
  rows <- list(); cells <- character(); cur <- ""
  for (el in body) {
    tag <- attr(el, "Rd_tag") %||% ""
    if (tag == "\\tab") { cells <- c(cells, trimws(cur)); cur <- "" }
    else if (tag == "\\cr") { cells <- c(cells, trimws(cur)); rows[[length(rows) + 1L]] <- cells; cells <- character(); cur <- "" }
    else cur <- paste0(cur, rd_md(el))
  }
  if (nzchar(trimws(cur)) || length(cells) > 0) rows[[length(rows) + 1L]] <- c(cells, trimws(cur))
  if (length(rows) == 0) return("")
  width <- max(vapply(rows, length, integer(1)))
  rows <- lapply(rows, function(r) c(r, rep("", width - length(r))))
  lines <- vapply(rows, function(r) paste0("| ", paste(r, collapse = " | "), " |"), character(1))
  sep <- paste0("|", paste(rep(" --- |", width), collapse = ""))
  paste0("\n\n", lines[1], "\n", sep, "\n", paste(lines[-1], collapse = "\n"), "\n\n")
}

#' Tidy a Markdown string produced from Rd
#' @keywords internal
md_tidy <- function(s) {
  s <- gsub("[ \t]+\n", "\n", s)
  s <- gsub("\n{3,}", "\n\n", s)
  s <- gsub("(?<!\n)\n(?![\n|-])", " ", s, perl = TRUE)
  s <- gsub("[ ]{2,}", " ", s)
  trimws(s)
}

#' Documentation of one help topic as a list of Markdown pieces
#'
#' @param rd An Rd object.
#' @returns A list with `title`, `description`, `details`, `sections`
#'   (named character), `arguments` (named character), `value`,
#'   `seealso`, `examples`.
#' @keywords internal
rd_doc <- function(rd) {
  sec <- function(tag) {
    el <- rd_section(rd, tag)
    if (is.null(el)) "" else md_tidy(rd_md(el))
  }
  sections <- list()
  for (el in rd_sections(rd, "\\section")) {
    sections[[trimws(rd_text(el[[1]]))]] <- md_tidy(rd_md(el[[2]]))
  }
  args <- list()
  arg_sec <- rd_section(rd, "\\arguments")
  if (!is.null(arg_sec)) {
    for (el in arg_sec) {
      if (identical(attr(el, "Rd_tag"), "\\item") && length(el) >= 2L) {
        nms <- trimws(strsplit(rd_text(el[[1]]), ",")[[1]])
        for (nm in nms) args[[nm]] <- md_tidy(rd_md(el[[2]]))
      }
    }
  }
  list(
    title = sec("\\title"),
    description = sec("\\description"),
    details = sec("\\details"),
    sections = sections,
    arguments = args,
    value = sec("\\value"),
    seealso = sec("\\seealso"),
    examples = md_tidy(rd_text(rd_section(rd, "\\examples") %||% "")),
    format = sec("\\format"),
    source = sec("\\source")
  )
}

#' A whole help topic as one Markdown document
#' @keywords internal
rd_topic_md <- function(rd, name) {
  d <- rd_doc(rd)
  parts <- c(paste0("# ", name, ": ", d$title), d$description)
  if (nzchar(d$details)) parts <- c(parts, "## Details", d$details)
  for (nm in names(d$sections)) parts <- c(parts, paste0("## ", nm), d$sections[[nm]])
  if (length(d$arguments) > 0) {
    parts <- c(parts, "## Arguments",
               paste0("- `", names(d$arguments), "`: ", unlist(d$arguments), collapse = "\n"))
  }
  if (nzchar(d$format)) parts <- c(parts, "## Format", d$format)
  if (nzchar(d$value)) parts <- c(parts, "## Value", d$value)
  if (nzchar(d$source)) parts <- c(parts, "## Source", d$source)
  if (nzchar(d$seealso)) parts <- c(parts, "## See also", d$seealso)
  if (nzchar(d$examples)) parts <- c(parts, "## Examples", paste0("```r\n", d$examples, "\n```"))
  paste(parts, collapse = "\n\n")
}
