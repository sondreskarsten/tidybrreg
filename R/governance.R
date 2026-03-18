#' Build a director interlock network
#'
#' Construct a bipartite graph of entities and persons linked by
#' board/officer roles. Returns a `tbl_graph` (tidygraph) object
#' suitable for centrality analysis and ggraph visualization.
#'
#' For a full ego network including sub-units, child entities, and
#' legal roles in addition to board roles, use [brreg_network()]
#' instead.
#'
#' @param org_nrs Character vector of organization numbers to include.
#'   Roles are fetched via [brreg_roles()] for each entity.
#' @param roles_data Optional pre-fetched roles tibble (from
#'   [brreg_roles()]). If provided, `org_nrs` is ignored.
#'
#' @returns A `tbl_graph` with two node types: `"entity"` (identified
#'   by `org_nr`) and `"person"` (identified by `person_id`). Edge
#'   attributes include `role_code`, `role_group_code`, and `org_nr`.
#'
#' @family tidybrreg governance functions
#' @seealso [brreg_network()] for full entity network graphs,
#'   [brreg_roles()] to fetch role data,
#'   [brreg_board_summary()] for board-level covariates.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet() && requireNamespace("tidygraph", quietly = TRUE)
#' \donttest{
#' net <- brreg_board_network(c("923609016", "984851006"))
#' net
#' }
brreg_board_network <- function(org_nrs = NULL, roles_data = NULL) {
  rlang::check_installed("tidygraph", reason = "for network construction.")

  if (is.null(roles_data)) {
    if (is.null(org_nrs) || length(org_nrs) == 0) {
      cli::cli_abort("Provide {.arg org_nrs} or {.arg roles_data}.")
    }
    roles_data <- dplyr::bind_rows(lapply(org_nrs, brreg_roles))
  }

  if (nrow(roles_data) == 0) {
    cli::cli_abort("No role data available to build network.")
  }

  entity_nodes <- tibble::tibble(
    name = unique(roles_data$org_nr),
    node_type = "entity"
  )
  if ("entity_name" %in% names(roles_data)) {
    entity_labels <- roles_data[!duplicated(roles_data$org_nr),
                                 c("org_nr", "entity_name"), drop = FALSE]
    entity_nodes <- dplyr::left_join(entity_nodes, entity_labels,
                                      by = c("name" = "org_nr"))
  }

  person_ids <- unique(roles_data$person_id[!is.na(roles_data$person_id)])
  person_nodes <- tibble::tibble(
    name = person_ids,
    node_type = "person"
  )
  if (all(c("first_name", "last_name") %in% names(roles_data))) {
    person_labels <- roles_data[!duplicated(roles_data$person_id),
                                 c("person_id", "first_name", "last_name"), drop = FALSE]
    person_nodes <- dplyr::left_join(person_nodes, person_labels,
                                      by = c("name" = "person_id"))
  }

  nodes <- dplyr::bind_rows(entity_nodes, person_nodes)

  edge_cols <- intersect(c("person_id", "org_nr", "role_code", "role_group_code"), names(roles_data))
  edges <- roles_data[!is.na(roles_data$person_id), edge_cols, drop = FALSE]
  names(edges)[names(edges) == "person_id"] <- "from"
  names(edges)[names(edges) == "org_nr"] <- "to"

  tidygraph::tbl_graph(nodes = nodes, edges = edges, directed = FALSE)
}


#' Prepare firm survival data
#'
#' Compute time-to-event and censoring indicators from entity
#' registration data, ready for use with `survival::Surv()` and
#' `flexsurv`.
#'
#' @param data A tibble from [brreg_download()], [brreg_search()],
#'   or [brreg_panel()]. Must contain at least `org_nr` and a
#'   date column for entry.
#' @param entry_var Column name for the entry date. Default
#'   `"founding_date"` (stiftelsesdato).
#' @param censoring_date Date at which surviving firms are
#'   right-censored. Default: today.
#'
#' @returns A tibble with added columns: `entry_date`, `exit_date`
#'   (Date or NA), `duration_years` (numeric), `event` (integer:
#'   1 = exit observed, 0 = right-censored). Compatible with
#'   `survival::Surv(duration_years, event)`.
#'
#' @family tidybrreg governance functions
#' @seealso [brreg_download()] for full register data.
#'
#' @export
#' @examplesIf interactive() && curl::has_internet()
#' \donttest{
#' firms <- brreg_search(legal_form = "AS", municipality_code = "0301",
#'                        max_results = 100)
#' surv <- brreg_survival_data(firms)
#' surv[, c("org_nr", "entry_date", "exit_date", "duration_years", "event")]
#' }
brreg_survival_data <- function(data,
                                 entry_var = "founding_date",
                                 censoring_date = Sys.Date()) {
  censoring_date <- as.Date(censoring_date)

  if (!entry_var %in% names(data)) {
    cli::cli_abort("Column {.val {entry_var}} not found in data.")
  }

  data$entry_date <- as.Date(data[[entry_var]])

  exit_hierarchy <- c("bankruptcy_date", "liquidation_date",
                       "forced_dissolution_date", "deletion_date")
  exit_cols <- intersect(exit_hierarchy, names(data))

  if (length(exit_cols) > 0) {
    exit_dates <- data[, exit_cols, drop = FALSE]
    exit_dates <- lapply(exit_dates, as.Date)
    data$exit_date <- do.call(pmin, c(exit_dates, na.rm = TRUE))
  } else {
    data$exit_date <- as.Date(NA)
  }

  data$event <- as.integer(!is.na(data$exit_date))
  end_date <- ifelse(is.na(data$exit_date), censoring_date, data$exit_date)
  end_date <- as.Date(end_date, origin = "1970-01-01")
  data$duration_years <- as.numeric(difftime(end_date, data$entry_date, units = "days")) / 365.25

  data$duration_years[data$duration_years < 0] <- NA_real_

  data
}
