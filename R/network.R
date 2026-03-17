#' Build an entity network graph
#'
#' Construct a `tbl_graph` (tidygraph) representing the relationships
#' around one or more seed entities. At depth 1, the graph includes
#' sub-units, child entities, role holders, and legal role targets —
#' all reachable via direct API calls. At depth 2, the graph expands
#' through person nodes to discover board interlocks, requiring local
#' bulk data (see Details).
#'
#' @section Depth and data requirements:
#' - **Depth 0**: Seed entity only. 1 API call per seed.
#' - **Depth 1**: Full ego network. 5-7 API calls per seed.
#' - **Depth 2**: Board interlocks via person-to-entity reverse lookup.
#'   Requires local bulk data for enheter, underenheter, and roller.
#'   Run [brreg_snapshot()] for each type first, or call with
#'   `download = TRUE` to trigger downloads interactively.
#'
#' @section Extensibility:
#' The `include` parameter controls which relationship types are
#' traversed. Each type maps to an internal collector function.
#' Future versions may add types such as `"addresses"`,
#' `"prior_owners"`, or `"accounting"`.
#'
#' @param org_nr Character vector of seed organization numbers.
#' @param depth Integer. 0 = seed only, 1 = ego network (default),
#'   2 = expand through persons (requires bulk data).
#' @param include Character vector of relationship types to include.
#'   Default includes all available types. Current types:
#'   `"underenheter"`, `"children"`, `"roles"`, `"legal_roles"`.
#' @param download Logical. If `TRUE` and depth > 1, offer to
#'   download missing bulk data interactively. Default `FALSE`.
#'
#' @returns A `tbl_graph` with node attributes `node_id`, `node_type`,
#'   `name`, `org_nr`, `person_id`, and edge attributes `from`, `to`,
#'   `edge_type`, `role_code`, `role`.
#'
#' @family tidybrreg governance functions
#' @seealso [brreg_entity()] for single lookups,
#'   [brreg_board_network()] for the roles-only subgraph,
#'   [brreg_status()] to check bulk data availability.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet() && requireNamespace("tidygraph", quietly = TRUE)
#' \donttest{
#' net <- brreg_network("923609016")
#' net
#'
#' tidygraph::as_tibble(net, "nodes")
#' tidygraph::as_tibble(net, "edges")
#' }
brreg_network <- function(org_nr,
                           depth   = 1L,
                           include = c("underenheter", "children", "roles", "legal_roles"),
                           download = FALSE) {
  rlang::check_installed("tidygraph", reason = "for network construction.")
  include <- match.arg(include, several.ok = TRUE)
  depth <- as.integer(depth)
  org_nr <- as.character(org_nr)

  collectors <- registry_collectors()
  active <- collectors[intersect(names(collectors), include)]

  nodes <- empty_nodes()
  edges <- empty_edges()

  for (seed in org_nr) {
    seed_result <- collect_seed(seed)
    nodes <- merge_nodes(nodes, seed_result$nodes)
    edges <- merge_edges(edges, seed_result$edges)

    if (depth >= 1L) {
      for (collector_fn in active) {
        result <- collector_fn(seed)
        nodes <- merge_nodes(nodes, result$nodes)
        edges <- merge_edges(edges, result$edges)
      }
    }
  }

  if (depth >= 2L) {
    expansion <- expand_depth_2(nodes, edges, org_nr, download = download)
    nodes <- merge_nodes(nodes, expansion$nodes)
    edges <- merge_edges(edges, expansion$edges)
  }

  build_tbl_graph(nodes, edges)
}


# =============================================================================
# COLLECTOR REGISTRY — add new relationship types here
# =============================================================================

registry_collectors <- function() {
  list(
    underenheter = collect_underenheter,
    children     = collect_children,
    roles        = collect_roles,
    legal_roles  = collect_legal_roles
  )
}


# =============================================================================
# SEED COLLECTOR
# =============================================================================

collect_seed <- function(org_nr) {
  entity <- brreg_entity(org_nr)
  node <- tibble::tibble(
    node_id   = paste0("o:", org_nr),
    node_type = entity$registry %||% "entity",
    name      = entity$name,
    org_nr    = org_nr,
    person_id = NA_character_
  )
  list(nodes = node, edges = empty_edges())
}


# =============================================================================
# DEPTH-1 COLLECTORS — each returns list(nodes, edges)
# =============================================================================

collect_underenheter <- function(org_nr) {
  subs <- brreg_underenheter(org_nr, max_results = 10000)
  if (nrow(subs) == 0) return(list(nodes = empty_nodes(), edges = empty_edges()))
  nodes <- tibble::tibble(
    node_id   = paste0("o:", subs$org_nr),
    node_type = "underenhet",
    name      = subs$name,
    org_nr    = subs$org_nr,
    person_id = NA_character_
  )
  edges <- tibble::tibble(
    from      = paste0("o:", org_nr),
    to        = paste0("o:", subs$org_nr),
    edge_type = "has_establishment",
    role_code = NA_character_,
    role      = NA_character_
  )
  list(nodes = nodes, edges = edges)
}


collect_children <- function(org_nr) {
  kids <- brreg_children(org_nr, max_results = 10000)
  if (nrow(kids) == 0) return(list(nodes = empty_nodes(), edges = empty_edges()))
  nodes <- tibble::tibble(
    node_id   = paste0("o:", kids$org_nr),
    node_type = "child_entity",
    name      = kids$name,
    org_nr    = kids$org_nr,
    person_id = NA_character_
  )
  edges <- tibble::tibble(
    from      = paste0("o:", org_nr),
    to        = paste0("o:", kids$org_nr),
    edge_type = "parent_of",
    role_code = NA_character_,
    role      = NA_character_
  )
  list(nodes = nodes, edges = edges)
}


collect_roles <- function(org_nr) {
  roles_data <- brreg_roles(org_nr)
  if (nrow(roles_data) == 0) return(list(nodes = empty_nodes(), edges = empty_edges()))

  person_rows <- roles_data[!is.na(roles_data$person_id), ]
  entity_rows <- roles_data[!is.na(roles_data$entity_org_nr), ]

  p_nodes <- if (nrow(person_rows) > 0) {
    deduped <- person_rows[!duplicated(person_rows$person_id), ]
    tibble::tibble(
      node_id   = paste0("p:", deduped$person_id),
      node_type = "person",
      name      = trimws(paste(deduped$first_name, deduped$last_name)),
      org_nr    = NA_character_,
      person_id = deduped$person_id
    )
  } else {
    empty_nodes()
  }

  e_nodes <- if (nrow(entity_rows) > 0) {
    deduped <- entity_rows[!duplicated(entity_rows$entity_org_nr), ]
    tibble::tibble(
      node_id   = paste0("o:", deduped$entity_org_nr),
      node_type = "role_holder_entity",
      name      = deduped$entity_name,
      org_nr    = deduped$entity_org_nr,
      person_id = NA_character_
    )
  } else {
    empty_nodes()
  }

  p_edges <- if (nrow(person_rows) > 0) {
    tibble::tibble(
      from      = paste0("p:", person_rows$person_id),
      to        = paste0("o:", org_nr),
      edge_type = "role",
      role_code = person_rows$role_code,
      role      = person_rows$role
    )
  } else {
    empty_edges()
  }

  e_edges <- if (nrow(entity_rows) > 0) {
    tibble::tibble(
      from      = paste0("o:", entity_rows$entity_org_nr),
      to        = paste0("o:", org_nr),
      edge_type = "entity_role",
      role_code = entity_rows$role_code,
      role      = entity_rows$role
    )
  } else {
    empty_edges()
  }

  list(
    nodes = dplyr::bind_rows(p_nodes, e_nodes),
    edges = dplyr::bind_rows(p_edges, e_edges)
  )
}


collect_legal_roles <- function(org_nr) {
  legal <- brreg_roles_legal(org_nr)
  if (nrow(legal) == 0) return(list(nodes = empty_nodes(), edges = empty_edges()))
  deduped <- legal[!duplicated(legal$target_org_nr), ]
  nodes <- tibble::tibble(
    node_id   = paste0("o:", deduped$target_org_nr),
    node_type = "legal_role_target",
    name      = deduped$target_name,
    org_nr    = deduped$target_org_nr,
    person_id = NA_character_
  )
  edges <- tibble::tibble(
    from      = paste0("o:", org_nr),
    to        = paste0("o:", legal$target_org_nr),
    edge_type = "legal_role",
    role_code = legal$role_code,
    role      = legal$role
  )
  list(nodes = nodes, edges = edges)
}


# =============================================================================
# DEPTH-2 EXPANSION — person → entity reverse lookup via bulk data
# =============================================================================

expand_depth_2 <- function(nodes, edges, seed_orgs, download = FALSE) {
  if (download) {
    require_bulk_data()
  } else {
    status <- brreg_status(quiet = TRUE)
    if (!status$all_ready) {
      require_bulk_data()
    }
  }

  bulk <- resolve_bulk_data()

  person_nodes <- nodes[nodes$node_type == "person" & !is.na(nodes$person_id), ]
  if (nrow(person_nodes) == 0) {
    return(list(nodes = empty_nodes(), edges = empty_edges()))
  }

  seed_persons <- unique(person_nodes$person_id)
  known_orgs <- unique(nodes$org_nr[!is.na(nodes$org_nr)])

  roller <- if (inherits(bulk$roller, "ArrowObject")) {
    bulk$roller |>
      dplyr::filter(.data$person_id %in% seed_persons) |>
      dplyr::collect()
  } else {
    bulk$roller[bulk$roller$person_id %in% seed_persons, ]
  }

  roller <- roller[!roller$org_nr %in% known_orgs, ]
  if (nrow(roller) == 0) {
    return(list(nodes = empty_nodes(), edges = empty_edges()))
  }

  new_orgs <- unique(roller$org_nr)

  enheter_match <- if (inherits(bulk$enheter, "ArrowObject")) {
    bulk$enheter |>
      dplyr::filter(.data$org_nr %in% new_orgs) |>
      dplyr::select(dplyr::any_of(c("org_nr", "name"))) |>
      dplyr::collect()
  } else {
    cols <- intersect(c("org_nr", "name"), names(bulk$enheter))
    bulk$enheter[bulk$enheter$org_nr %in% new_orgs, cols, drop = FALSE]
  }

  under_match <- if (inherits(bulk$underenheter, "ArrowObject")) {
    bulk$underenheter |>
      dplyr::filter(.data$org_nr %in% new_orgs) |>
      dplyr::select(dplyr::any_of(c("org_nr", "name"))) |>
      dplyr::collect()
  } else {
    cols <- intersect(c("org_nr", "name"), names(bulk$underenheter))
    bulk$underenheter[bulk$underenheter$org_nr %in% new_orgs, cols, drop = FALSE]
  }

  all_found <- dplyr::bind_rows(
    if (nrow(enheter_match) > 0) dplyr::mutate(enheter_match, node_type = "entity") else NULL,
    if (nrow(under_match) > 0) dplyr::mutate(under_match, node_type = "underenhet") else NULL
  )
  all_found <- all_found[!duplicated(all_found$org_nr), ]

  new_nodes <- tibble::tibble(
    node_id   = paste0("o:", all_found$org_nr),
    node_type = all_found$node_type,
    name      = all_found$name,
    org_nr    = all_found$org_nr,
    person_id = NA_character_
  )

  new_edges <- tibble::tibble(
    from      = paste0("p:", roller$person_id),
    to        = paste0("o:", roller$org_nr),
    edge_type = "role",
    role_code = roller$role_code,
    role      = roller$role
  )

  list(nodes = new_nodes, edges = new_edges)
}


# =============================================================================
# GRAPH ASSEMBLY HELPERS
# =============================================================================

empty_nodes <- function() {
  tibble::tibble(
    node_id   = character(),
    node_type = character(),
    name      = character(),
    org_nr    = character(),
    person_id = character()
  )
}

empty_edges <- function() {
  tibble::tibble(
    from      = character(),
    to        = character(),
    edge_type = character(),
    role_code = character(),
    role      = character()
  )
}

merge_nodes <- function(a, b) {
  combined <- dplyr::bind_rows(a, b)
  combined[!duplicated(combined$node_id), ]
}

merge_edges <- function(a, b) {
  dplyr::bind_rows(a, b)
}

build_tbl_graph <- function(nodes, edges) {
  if (nrow(nodes) == 0) {
    cli::cli_abort("No nodes to build graph from.")
  }
  edges <- edges[edges$from %in% nodes$node_id & edges$to %in% nodes$node_id, ]
  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = TRUE, node_key = "node_id")
}
