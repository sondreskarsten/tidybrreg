# Live API audit tests for functions that moved to tidybrregpanel.

test_that("brreg_board_summary: Equinor expected board structure", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 bs <- brreg_board_summary(roles)
 expect_equal(nrow(bs), 1)
 # Equinor is a major ASA — board must have at least 5 members
 expect_gt(bs$board_size, 5L)
 expect_true(bs$has_ceo)
 expect_true(bs$has_auditor)
 expect_true(is.integer(bs$board_size))
 expect_true(is.logical(bs$has_ceo))
 expect_true(is.logical(bs$has_auditor))
})

test_that("brreg_board_network: bipartite graph from live data", {
 skip_if_no_api()
 skip_if_not_installed("tidygraph")

 roles <- safely(brreg_roles("923609016"))
 net <- brreg_board_network(roles_data = roles)
 expect_s3_class(net, "tbl_graph")

 nodes <- tidygraph::as_tibble(net, "nodes")
 edges <- tidygraph::as_tibble(net, "edges")

 # Must have both entity and person nodes
 expect_true("entity" %in% nodes$node_type)
 expect_true("person" %in% nodes$node_type)
 # No NA node names
 expect_true(all(!is.na(nodes$name)))
 # Edges should exist
 expect_gt(nrow(edges), 0)
})

test_that("brreg_network: depth=0 returns seed-only graph", {
 skip_if_no_api()
 skip_if_not_installed("tidygraph")

 net <- safely(brreg_network("923609016", depth = 0))
 expect_s3_class(net, "tbl_graph")

 nodes <- tidygraph::as_tibble(net, "nodes")
 expect_equal(nrow(nodes), 1)
 expect_equal(nodes$org_nr, "923609016")
 expect_match(nodes$name, "EQUINOR", fixed = TRUE)
})

test_that("brreg_network: depth=1 expands to ego network", {
 skip_if_no_api()
 skip_if_not_installed("tidygraph")

 net <- safely(brreg_network("923609016", depth = 1))
 expect_s3_class(net, "tbl_graph")

 nodes <- tidygraph::as_tibble(net, "nodes")
 edges <- tidygraph::as_tibble(net, "edges")

 # Should have multiple node types
 expect_true(length(unique(nodes$node_type)) > 1)
 # Should include person nodes from roles
 expect_true("person" %in% nodes$node_type)
 # Should include edges
 expect_gt(nrow(edges), 0)
 # Edge types should include role and structural relationships
 expect_true(any(edges$edge_type == "role"))
 # Node count should be substantial for a major company
 expect_gt(nrow(nodes), 10)
})

test_that("brreg_harmonize_kommune: remaps old municipality codes", {
 skip_if_no_api()
 skip_if_not_installed("klassR")

 df <- tibble::tibble(municipality_code = c("0301", "1103"))
 result <- tryCatch(
   brreg_harmonize_kommune(df),
   error = function(e) {
     skip(paste("SSB KLASS unavailable:", conditionMessage(e)))
   }
 )

 expect_true("municipality_code_harmonized" %in% names(result))
 expect_true("municipality_code_target_name" %in% names(result))
 # Oslo (0301) should map to itself or its current code
 expect_true(!is.na(result$municipality_code_harmonized[1]))
})

test_that("brreg_harmonize_nace: SN2007 to SN2025 mapping", {
 skip_if_no_api()
 skip_if_not_installed("klassR")

 df <- tibble::tibble(nace_1 = c("06.100", "64.190", "62.010"))
 result <- tryCatch(
   brreg_harmonize_nace(df, from = "SN2007", to = "SN2025"),
   error = function(e) {
     skip(paste("SSB KLASS unavailable:", conditionMessage(e)))
   }
 )

 expect_true("nace_1_harmonized" %in% names(result))
 expect_true("nace_1_ambiguous" %in% names(result))
 expect_type(result$nace_1_ambiguous, "logical")
 # Harmonized codes should be non-empty strings
 expect_true(all(nchar(result$nace_1_harmonized) > 0))
})

test_that("roles vs board_summary: CEO presence consistent", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 bs <- brreg_board_summary(roles)
 # board_summary says has_ceo; verify DAGL role actually exists
 expect_true(bs$has_ceo)
 expect_true(any(roles$role_group_code == "DAGL"))
 # board_summary says has_auditor; verify REVI role actually exists
 expect_true(bs$has_auditor)
 expect_true(any(roles$role_group_code == "REVI"))
})

test_that("survival_data: entry_date matches entity founding_date", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 surv <- brreg_survival_data(eq)
 expect_equal(surv$entry_date, eq$founding_date)
 # Equinor is not bankrupt/dissolved, so event should be 0 (right-censored)
 expect_equal(surv$event, 0L)
 expect_true(surv$duration_years > 50)  # Founded in 1972
})

test_that("brreg_status: returns correct structure", {
 status <- brreg_status(quiet = TRUE)
 expect_type(status, "list")
 expect_true(all(c("available", "missing", "all_ready") %in% names(status)))
 expect_type(status$all_ready, "logical")
 expect_type(status$available, "character")
 expect_type(status$missing, "character")
})
