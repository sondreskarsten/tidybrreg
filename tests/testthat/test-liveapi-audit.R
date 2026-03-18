# Comprehensive live API audit — expected vs observed
# Tests every API-facing exported function against the real brreg + SSB APIs.
# Compares expected ground-truth values for known entities to actual API responses.
#
# Run with:
#   NOT_CRAN=true TIDYBRREG_LIVE_API=true \
#     Rscript -e 'testthat::test_file("tests/testthat/test-liveapi-audit.R")'
#
# Ground truth entities (stable, well-known):
#   Equinor ASA       923609016  —  ASA, oil & gas, Stavanger
#   DNB Bank ASA      984851006  —  ASA, banking, Oslo
#   Stortinget        971524960  —  ORGL, parliament, Oslo
#   Norges Bank        937884117  —  ORGL, central bank, Oslo

# ============================================================================
# Section 1: Entity Lookup — Expected vs Observed
# ============================================================================

test_that("brreg_entity: Equinor ground truth", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 expect_s3_class(eq, "tbl_df")
 expect_equal(nrow(eq), 1)
 # Exact matches on stable fields
 expect_equal(eq$org_nr, "923609016")
 expect_equal(eq$name, "EQUINOR ASA")
 expect_equal(eq$legal_form, "ASA")
 expect_equal(eq$founding_date, as.Date("1972-09-18"))
 expect_equal(eq$nace_1, "06.100")
 expect_equal(eq$bankrupt, FALSE)
 expect_equal(eq$registry, "enheter")
 # Semi-stable: municipality (Stavanger, merged 2020)
 expect_true(eq$municipality_code %in% c("1103", "4601"))
 # Range checks for volatile fields
 expect_true(is.integer(eq$employees))
 expect_gt(eq$employees, 1000L)
 # Type checks
 expect_s3_class(eq$founding_date, "Date")
 expect_true(is.character(eq$municipality_code))
})

test_that("brreg_entity: DNB ground truth", {
 skip_if_no_api()
 dnb <- safely(brreg_entity("984851006"))
 expect_equal(dnb$org_nr, "984851006")
 expect_match(dnb$name, "DNB", fixed = TRUE)
 expect_equal(dnb$legal_form, "ASA")
 expect_equal(dnb$municipality_code, "0301")
 expect_equal(dnb$bankrupt, FALSE)
 expect_gt(dnb$employees, 100L)
})

test_that("brreg_entity: Norges Bank ground truth", {
 skip_if_no_api()
 nb <- safely(brreg_entity("937884117"))
 expect_equal(nb$org_nr, "937884117")
 expect_match(nb$name, "NORGES BANK", fixed = TRUE)
 expect_equal(nb$municipality_code, "0301")
 expect_equal(nb$bankrupt, FALSE)
 expect_s3_class(nb$founding_date, "Date")
})

test_that("brreg_entity: Stortinget ground truth", {
 skip_if_no_api()
 st <- safely(brreg_entity("971524960"))
 expect_equal(st$org_nr, "971524960")
 expect_match(st$name, "STORTINGET", fixed = TRUE)
 expect_equal(st$legal_form, "ORGL")
 expect_equal(st$municipality_code, "0301")
})

test_that("brreg_entity: type=label translates codes to English", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016", type = "label"))
 # legal_form "ASA" should become a descriptive English term
 expect_match(eq$legal_form, "company|public", ignore.case = TRUE)
 # nace_1 should be a textual description, not just the code "06.100"
 expect_true(nchar(eq$nace_1) > 6)
 expect_match(eq$nace_1, "petroleum|oil|extraction", ignore.case = TRUE)
})

test_that("brreg_entity: auto-detect finds underenhet", {
 skip_if_no_api()
 subs <- safely(brreg_underenheter("923609016", max_results = 1))
 if (nrow(subs) > 0) {
   sub_nr <- subs$org_nr[1]
   result <- safely(brreg_entity(sub_nr, registry = "auto"))
   expect_equal(result$org_nr, sub_nr)
   expect_equal(result$registry, "underenheter")
 }
})

test_that("brreg_entity: registry=enheter forces main entity lookup", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016", registry = "enheter"))
 expect_equal(eq$registry, "enheter")
})

test_that("brreg_entity: zero-drop policy — unknown API fields pass through", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 # Should have more columns than field_dict rows (extra API fields as snake_case)
 expect_gt(ncol(eq), nrow(field_dict))
})

test_that("brreg_entity: validates org_nr format before API call", {
 expect_error(brreg_entity("123456789"), "Invalid")
 expect_error(brreg_entity("12345"), "Invalid")
 expect_error(brreg_entity("abcdefghi"), "Invalid")
})

test_that("brreg_entity: 404 for non-existent entity", {
 skip_if_no_api()
 safely(expect_error(brreg_entity("999999999"), "not found"))
})

test_that("brreg_entity: all field_dict types are correctly coerced", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 # Date columns
 expect_s3_class(eq$founding_date, "Date")
 expect_s3_class(eq$registration_date, "Date")
 # Integer columns
 expect_true(is.integer(eq$employees))
 # Logical columns
 expect_true(is.logical(eq$bankrupt))
 expect_true(is.logical(eq$under_liquidation))
 # Character columns
 expect_true(is.character(eq$org_nr))
 expect_true(is.character(eq$name))
 expect_true(is.character(eq$legal_form))
})

# ============================================================================
# Section 2: Search — Expected vs Observed
# ============================================================================

test_that("brreg_search: name search finds Equinor", {
 skip_if_no_api()
 s <- safely(brreg_search(name = "Equinor", max_results = 5))
 expect_s3_class(s, "tbl_df")
 expect_gt(nrow(s), 0)
 expect_true("923609016" %in% s$org_nr)
 total <- attr(s, "total_matches")
 expect_false(is.null(total))
 expect_true(total >= nrow(s))
})

test_that("brreg_search: legal_form=ASA filter enforced", {
 skip_if_no_api()
 s <- safely(brreg_search(legal_form = "ASA", max_results = 10))
 expect_gt(nrow(s), 0)
 expect_true(all(s$legal_form == "ASA"))
})

test_that("brreg_search: municipality + employees filter", {
 skip_if_no_api()
 s <- safely(brreg_search(legal_form = "AS", municipality_code = "0301",
                           min_employees = 1000, max_results = 5))
 expect_gt(nrow(s), 0)
 expect_true(all(s$legal_form == "AS"))
})

test_that("brreg_search: nace_code filter returns matching entities", {
 skip_if_no_api()
 s <- safely(brreg_search(nace_code = "64.190", max_results = 5))
 expect_gt(nrow(s), 0)
})

test_that("brreg_search: bankrupt filter returns bankrupt entities", {
 skip_if_no_api()
 s <- safely(brreg_search(bankrupt = TRUE, max_results = 5))
 if (nrow(s) > 0) {
   expect_true(all(s$bankrupt))
 }
})

test_that("brreg_search: empty result returns 0-row tibble with attributes", {
 skip_if_no_api()
 s <- safely(brreg_search(name = "ZZZZNOTEXIST999QQQQQ", max_results = 5))
 expect_equal(nrow(s), 0)
 expect_s3_class(s, "tbl_df")
 total <- attr(s, "total_matches")
 expect_equal(total, 0L)
})

test_that("brreg_search: max_results is respected", {
 skip_if_no_api()
 s <- safely(brreg_search(name = "AS", max_results = 3))
 expect_lte(nrow(s), 3)
})

test_that("brreg_search: type=label translates codes", {
 skip_if_no_api()
 s <- safely(brreg_search(name = "Equinor", max_results = 2, type = "label"))
 expect_gt(nrow(s), 0)
 # legal_form should be a descriptive string, not a 2-3 char code
 expect_true(all(nchar(s$legal_form) > 3))
})

test_that("brreg_search: underenheter registry", {
 skip_if_no_api()
 s <- safely(brreg_search(name = "Equinor", registry = "underenheter",
                           max_results = 5))
 expect_s3_class(s, "tbl_df")
 # Underenheter search should return rows (Equinor has many sub-units)
 expect_gt(nrow(s), 0)
})

test_that("brreg_search: pagination beyond page 1 works", {
 skip_if_no_api()
 # Request enough results to trigger pagination (page size = 20 by default)
 s <- safely(brreg_search(legal_form = "ASA", max_results = 25))
 expect_gt(nrow(s), 20)
 expect_lte(nrow(s), 25)
 # All org_nrs should be unique
 expect_equal(length(unique(s$org_nr)), nrow(s))
})

# ============================================================================
# Section 3: Underenheter & Children
# ============================================================================

test_that("brreg_underenheter: Equinor has sub-units", {
 skip_if_no_api()
 subs <- safely(brreg_underenheter("923609016", max_results = 10))
 expect_s3_class(subs, "tbl_df")
 expect_gt(nrow(subs), 0)
 # All org_nrs should be valid 9-digit numbers
 expect_true(all(grepl("^\\d{9}$", subs$org_nr)))
 # All should be distinct from parent
 expect_true(!("923609016" %in% subs$org_nr))
})

test_that("brreg_underenheter: parent_org_nr links back to seed", {
 skip_if_no_api()
 subs <- safely(brreg_underenheter("923609016", max_results = 5))
 if (nrow(subs) > 0 && "parent_org_nr" %in% names(subs)) {
   expect_true(all(subs$parent_org_nr == "923609016"))
 }
})

test_that("brreg_children: Stortinget hierarchy (ORGL children)", {
 skip_if_no_api()
 children <- safely(brreg_children("971524960", max_results = 10))
 expect_s3_class(children, "tbl_df")
 # Stortinget may have child entities (e.g. Riksrevisjonen)
 # Structure must be correct even if empty
 expect_true("org_nr" %in% names(children))
 expect_true("name" %in% names(children))
})

test_that("brreg_children: children are enheter not underenheter", {
 skip_if_no_api()
 children <- safely(brreg_children("971524960", max_results = 5))
 if (nrow(children) > 0) {
   # Look up the first child — should be in enheter registry
   child <- safely(brreg_entity(children$org_nr[1], registry = "enheter"))
   expect_equal(child$registry, "enheter")
 }
})

# ============================================================================
# Section 4: Roles & Governance — Expected vs Observed
# ============================================================================

test_that("brreg_roles: Equinor has expected role groups", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 expect_s3_class(roles, "tbl_df")
 expect_gt(nrow(roles), 0)

 # Column schema
 expected_cols <- c("org_nr", "role_group", "role_group_code", "role",
                    "role_code", "first_name", "last_name", "person_id",
                    "birth_date", "deceased", "resigned")
 for (col in expected_cols) {
   expect_true(col %in% names(roles), label = paste("Column", col, "exists"))
 }

 # Equinor must have board (STYR), CEO (DAGL), and auditor (REVI)
 expect_true("STYR" %in% roles$role_group_code)
 expect_true("DAGL" %in% roles$role_group_code)
 expect_true("REVI" %in% roles$role_group_code)
})

test_that("brreg_roles: English labels are present", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 # role_group should have English labels
 expect_true(any(grepl("Board|Director|CEO|Auditor", roles$role_group)))
 # role should have English labels
 expect_true(any(grepl("Chair|Member|CEO|Auditor|Managing|Deputy", roles$role)))
})

test_that("brreg_roles: birth_date is Date, person_id is well-formed", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 expect_s3_class(roles$birth_date, "Date")

 person_roles <- roles[!is.na(roles$person_id), ]
 expect_gt(nrow(person_roles), 0)
 # person_id format: YYYY-MM-DD_lastname_firstname[_middlename]
 expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2}_", person_roles$person_id)))
})

test_that("brreg_roles: entity-held roles (auditor firm)", {
 skip_if_no_api()
 roles <- safely(brreg_roles("923609016"))
 entity_roles <- roles[!is.na(roles$entity_org_nr), ]
 # Equinor should have an auditor firm
 expect_gt(nrow(entity_roles), 0)
 # entity_org_nr should be a valid 9-digit number
 expect_true(all(grepl("^\\d{9}$", entity_roles$entity_org_nr)))
})

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

test_that("brreg_roles_legal: Equinor holds roles in subsidiaries", {
 skip_if_no_api()
 legal <- safely(brreg_roles_legal("923609016"))
 expect_s3_class(legal, "tbl_df")
 if (nrow(legal) > 0) {
   expect_true(all(c("org_nr", "target_org_nr", "role_code", "role") %in% names(legal)))
   # All target_org_nr should be valid 9-digit strings
   expect_true(all(grepl("^\\d{9}$", legal$target_org_nr)))
   # org_nr should be the seed entity
   expect_true(all(legal$org_nr == "923609016"))
 }
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

# ============================================================================
# Section 5: CDC Updates — All 3 Streams
# ============================================================================

test_that("brreg_updates: enheter stream structure and monotonicity", {
 skip_if_no_api()
 u <- safely(brreg_updates(since = Sys.Date() - 3, size = 50))
 expect_s3_class(u, "tbl_df")
 expect_gt(nrow(u), 0)

 # Required columns
 expect_true(all(c("update_id", "org_nr", "change_type", "timestamp") %in% names(u)))

 # Type checks
 expect_type(u$update_id, "integer")
 expect_type(u$org_nr, "character")
 expect_s3_class(u$timestamp, "POSIXct")

 # change_type values
 expect_true(all(u$change_type %in% c("Ny", "Endring", "Sletting", "Ukjent")))

 # Monotonically increasing update_ids
 if (nrow(u) > 1) {
   expect_true(all(diff(u$update_id) >= 0))
 }

 # Timestamps should be recent (within last week)
 expect_true(all(u$timestamp > as.POSIXct(Sys.Date() - 7)))

 # org_nrs should be valid 9-digit strings
 expect_true(all(grepl("^\\d{9}$", u$org_nr)))
})

test_that("brreg_updates: include_changes provides RFC 6902 patches", {
 skip_if_no_api()
 u <- safely(brreg_updates(since = Sys.Date() - 3, size = 100,
                            include_changes = TRUE))
 endring_rows <- u[u$change_type == "Endring", ]
 if (nrow(endring_rows) > 0 && "changes" %in% names(u)) {
   first_endring <- endring_rows$changes[[1]]
   if (!is.null(first_endring) && nrow(first_endring) > 0) {
     expect_true(all(c("operation", "field", "new_value") %in% names(first_endring)))
   }
 }
})

test_that("brreg_updates: underenheter stream works", {
 skip_if_no_api()
 u <- safely(brreg_updates(since = Sys.Date() - 3, size = 10,
                            type = "underenheter"))
 expect_s3_class(u, "tbl_df")
 expect_gt(nrow(u), 0)
 expect_true(all(c("update_id", "org_nr", "change_type", "timestamp") %in% names(u)))
 expect_type(u$update_id, "integer")
 expect_true(all(grepl("^\\d{9}$", u$org_nr)))
})

test_that("brreg_updates: roller stream works (CloudEvents)", {
 skip_if_no_api()
 u <- safely(brreg_updates(since = Sys.Date() - 3, size = 10,
                            type = "roller"))
 expect_s3_class(u, "tbl_df")
 expect_gt(nrow(u), 0)
 expect_true(all(c("update_id", "org_nr", "change_type", "timestamp") %in% names(u)))
 expect_type(u$update_id, "integer")
 expect_s3_class(u$timestamp, "POSIXct")
 expect_true(all(grepl("^\\d{9}$", u$org_nr)))
})

# ============================================================================
# Section 6: Labels & Dictionaries — Expected vs Observed
# ============================================================================

test_that("get_brreg_dic: NACE dictionary has expected content", {
 skip_if_no_api()
 d <- safely(get_brreg_dic("nace"))
 expect_s3_class(d, "tbl_df")
 expect_gt(nrow(d), 1500)
 expect_true(all(c("code", "name_en", "level") %in% names(d)))
 # Ground truth: code 06.100 is oil extraction
 row_06100 <- d[d$code == "06.100", ]
 expect_equal(nrow(row_06100), 1)
 expect_match(row_06100$name_en, "petroleum|oil|crude", ignore.case = TRUE)
})

test_that("get_brreg_dic: sector dictionary has expected content", {
 skip_if_no_api()
 d <- safely(get_brreg_dic("sector"))
 expect_s3_class(d, "tbl_df")
 expect_gt(nrow(d), 10)
 expect_true(all(c("code", "name_en") %in% names(d)))
})

test_that("get_brreg_dic: caching returns identical object", {
 skip_if_no_api()
 d1 <- safely(get_brreg_dic("nace"))
 d2 <- safely(get_brreg_dic("nace"))
 expect_identical(d1, d2)
})

test_that("brreg_label: vector mode translates legal_form codes", {
 result <- brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form")
 expect_type(result, "character")
 expect_length(result, 3)
 # AS → "Private limited company" or similar
 expect_match(result[1], "company|limited", ignore.case = TRUE)
 # ASA → "Public limited company" or similar
 expect_match(result[2], "company|public", ignore.case = TRUE)
 # All should be longer than the original code
 expect_true(all(nchar(result) > 2))
})

test_that("brreg_label: data frame mode translates entity", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 labeled <- brreg_label(eq)
 # legal_form should now be English text
 expect_match(labeled$legal_form, "company|public", ignore.case = TRUE)
})

test_that("brreg_label: code argument preserves original in *_code column", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 labeled <- brreg_label(eq, code = "legal_form")
 expect_true("legal_form_code" %in% names(labeled))
 expect_equal(labeled$legal_form_code, "ASA")
 # The main column should be the translated label
 expect_match(labeled$legal_form, "company|public", ignore.case = TRUE)
})

test_that("brreg_label: errors without dic for vector input", {
 expect_error(brreg_label(c("AS", "ASA")), "dic")
})

test_that("brreg_label: NACE label for known codes", {
 skip_if_no_api()
 result <- brreg_label(c("06.100", "64.190"), dic = "nace")
 expect_type(result, "character")
 expect_length(result, 2)
 # Both should be descriptive text, not just codes
 expect_true(all(nchar(result) > 6))
})

# ============================================================================
# Section 7: Harmonization (SSB KLASS API)
# ============================================================================

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

# ============================================================================
# Section 8: Cross-Function Consistency
# ============================================================================

test_that("entity and search return consistent data for Equinor", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 s <- safely(brreg_search(name = "EQUINOR ASA", max_results = 5))

 match_row <- s[s$org_nr == "923609016", ]
 if (nrow(match_row) > 0) {
   expect_equal(eq$legal_form, match_row$legal_form)
   expect_equal(eq$name, match_row$name)
   expect_equal(eq$nace_1, match_row$nace_1)
   expect_equal(eq$municipality_code, match_row$municipality_code)
 }
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

test_that("underenheter count matches search count", {
 skip_if_no_api()
 subs <- safely(brreg_underenheter("923609016", max_results = 100))
 s <- safely(brreg_search(parent_org_nr = "923609016",
                           registry = "underenheter", max_results = 100))
 # Both approaches should find the same (or very similar) count
 expect_equal(nrow(subs), nrow(s), tolerance = 2)
})

# ============================================================================
# Section 9: Reference Data Integrity
# ============================================================================

test_that("field_dict: complete and internally consistent", {
 expect_true(all(c("api_path", "col_name", "type") %in% names(field_dict)))
 expect_gt(nrow(field_dict), 40)
 # col_names must be unique
 expect_equal(length(unique(field_dict$col_name)), nrow(field_dict))
 # types must be valid R types
 expect_true(all(field_dict$type %in% c("character", "Date", "integer", "logical")))
})

test_that("field_dict: covers live API response", {
 skip_if_no_api()
 eq <- safely(brreg_entity("923609016"))
 # At least 70% of dict columns should be present for a major entity
 present <- sum(field_dict$col_name %in% names(eq))
 expect_gt(present / nrow(field_dict), 0.7)
})

test_that("legal_forms: has expected codes", {
 expect_true("AS" %in% legal_forms$code)
 expect_true("ASA" %in% legal_forms$code)
 expect_true("ENK" %in% legal_forms$code)
 expect_true(all(c("code", "name_en") %in% names(legal_forms)))
})

test_that("role_types: has expected codes", {
 expect_true("LEDE" %in% role_types$code)
 expect_true("MEDL" %in% role_types$code)
 expect_true("DAGL" %in% role_types$code)
 expect_true(all(c("code", "name_en") %in% names(role_types)))
})

test_that("role_groups: has expected codes", {
 expect_true("STYR" %in% role_groups$code)
 expect_true("DAGL" %in% role_groups$code)
 expect_true("REVI" %in% role_groups$code)
 expect_true(all(c("code", "name_en") %in% names(role_groups)))
})

# ============================================================================
# Section 10: Validation
# ============================================================================

test_that("brreg_validate: known valid org numbers pass", {
 expect_true(brreg_validate("923609016"))   # Equinor
 expect_true(brreg_validate("984851006"))   # DNB
 expect_true(brreg_validate("937884117"))   # Norges Bank
 expect_true(brreg_validate("971524960"))   # Stortinget
})

test_that("brreg_validate: invalid numbers fail", {
 expect_false(brreg_validate("123456789"))
 expect_false(brreg_validate("000000000"))
 expect_false(brreg_validate("12345"))
 expect_false(brreg_validate("abcdefghi"))
})

# ============================================================================
# Section 11: Download & Status (argument validation, no bulk downloads)
# ============================================================================

test_that("brreg_download: validates type argument", {
 expect_error(brreg_download(type = "invalid"), "should be one of")
})

test_that("brreg_download: validates format argument", {
 expect_error(brreg_download(format = "invalid"), "should be one of")
})

test_that("brreg_download: validates type_output argument", {
 expect_error(brreg_download(type_output = "invalid"), "should be one of")
})

test_that("brreg_status: returns correct structure", {
 status <- brreg_status(quiet = TRUE)
 expect_type(status, "list")
 expect_true(all(c("available", "missing", "all_ready") %in% names(status)))
 expect_type(status$all_ready, "logical")
 expect_type(status$available, "character")
 expect_type(status$missing, "character")
})

# ============================================================================
# Section 12: Rate Limiting & Error Handling
# ============================================================================

test_that("rapid sequential requests succeed (rate limiting works)", {
 skip_if_no_api()
 orgs <- c("923609016", "984851006", "937884117", "971524960", "982463718")
 results <- list()
 for (org in orgs) {
   results[[org]] <- safely(brreg_entity(org))
 }
 for (org in orgs) {
   expect_s3_class(results[[org]], "tbl_df")
   expect_equal(nrow(results[[org]]), 1)
   expect_equal(results[[org]]$org_nr, org)
 }
})

# ============================================================================
# Section 13: ENK (sole proprietorship) edge case
# ============================================================================

test_that("parse_entity handles ENK with minimal fields", {
 skip_if_no_api()
 s <- safely(brreg_search(legal_form = "ENK", max_results = 1))
 if (nrow(s) > 0) {
   enk <- safely(brreg_entity(s$org_nr[1]))
   expect_s3_class(enk, "tbl_df")
   expect_equal(nrow(enk), 1)
   expect_equal(enk$legal_form, "ENK")
   # ENK may have NA for employees — that's expected
   expect_true(is.integer(enk$employees) || is.na(enk$employees))
 }
})

# ============================================================================
# Section 14: Internal helpers
# ============================================================================

test_that("to_snake: converts camelCase correctly", {
 expect_equal(tidybrreg:::to_snake("organisasjonsnummer"), "organisasjonsnummer")
 expect_equal(tidybrreg:::to_snake("antallAnsatte"), "antall_ansatte")
 expect_equal(tidybrreg:::to_snake("forretningsadresse.kommune"),
              "forretningsadresse_kommune")
 expect_equal(tidybrreg:::to_snake("naeringskode1.kode"), "naeringskode1_kode")
})
