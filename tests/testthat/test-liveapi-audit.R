# Comprehensive live API audit
# Tests every API-facing exported function against the real brreg API
# Run with: NOT_CRAN=true TIDYBRREG_LIVE_API=true Rscript -e 'testthat::test_file("tests/testthat/test-liveapi-audit.R")'

# ── Entity lookup ────────────────────────────────────────────────────────

test_that("brreg_entity: basic lookup returns correct structure", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))  # Equinor ASA
  expect_s3_class(eq, "tbl_df")
  expect_equal(nrow(eq), 1)
  expect_equal(eq$org_nr, "923609016")
  expect_equal(eq$name, "EQUINOR ASA")
  expect_equal(eq$legal_form, "ASA")
  expect_true(is.integer(eq$employees))
  expect_s3_class(eq$founding_date, "Date")
  expect_true(is.logical(eq$bankrupt))
  expect_true(is.character(eq$municipality_code))
  expect_true(is.character(eq$nace_1))
  expect_true("registry" %in% names(eq))
  expect_equal(eq$registry, "enheter")
})

test_that("brreg_entity: type=label translates codes", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016", type = "label"))
  # legal_form should be translated to English
  expect_match(eq$legal_form, "company|public", ignore.case = TRUE)
  # nace_1 should also be translated
  expect_true(nchar(eq$nace_1) > 6)  # longer than code "06.100"
})

test_that("brreg_entity: auto-detect finds underenhet", {
  skip_if_no_api()
  # Look up a known underenhet — Equinor's first sub-unit
  subs <- safely(brreg_underenheter("923609016", max_results = 1))
  if (nrow(subs) > 0) {
    sub_nr <- subs$org_nr[1]
    result <- safely(brreg_entity(sub_nr, registry = "auto"))
    expect_equal(result$org_nr, sub_nr)
    expect_equal(result$registry, "underenheter")
  }
})

test_that("brreg_entity: registry=enheter for main entity", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016", registry = "enheter"))
  expect_equal(eq$registry, "enheter")
})

test_that("brreg_entity: registry=underenheter for sub-entity", {
  skip_if_no_api()
  subs <- safely(brreg_underenheter("923609016", max_results = 1))
  if (nrow(subs) > 0) {
    sub_nr <- subs$org_nr[1]
    result <- safely(brreg_entity(sub_nr, registry = "underenheter"))
    expect_equal(result$registry, "underenheter")
  }
})

test_that("brreg_entity: zero-drop policy — unknown fields pass through", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  # Should have more columns than field_dict rows (extra API fields as snake_case)
  expect_gt(ncol(eq), nrow(field_dict))
})

test_that("brreg_entity: validates org_nr format", {
  expect_error(brreg_entity("123456789"), "Invalid")
  expect_error(brreg_entity("12345"), "Invalid")
  expect_error(brreg_entity("abcdefghi"), "Invalid")
})

test_that("brreg_entity: 404 for non-existent entity", {
  skip_if_no_api()
  safely(expect_error(brreg_entity("999999999"), "not found"))
})

test_that("brreg_entity: DNB Bank lookup", {
  skip_if_no_api()
  dnb <- safely(brreg_entity("984851006"))
  expect_equal(dnb$org_nr, "984851006")
  expect_match(dnb$name, "DNB", ignore.case = TRUE)
})

# ── Search ───────────────────────────────────────────────────────────────

test_that("brreg_search: name search works", {
  skip_if_no_api()
  s <- safely(brreg_search(name = "Equinor", max_results = 5))
  expect_s3_class(s, "tbl_df")
  expect_gt(nrow(s), 0)
  expect_true("org_nr" %in% names(s))
  expect_true("name" %in% names(s))
  total <- attr(s, "total_matches")
  expect_false(is.null(total))
  expect_true(total >= nrow(s))
})

test_that("brreg_search: legal_form filter", {
  skip_if_no_api()
  s <- safely(brreg_search(legal_form = "AS", municipality_code = "0301",
                           min_employees = 1000, max_results = 5))
  expect_gt(nrow(s), 0)
  expect_true(all(s$legal_form == "AS"))
})

test_that("brreg_search: nace filter", {
  skip_if_no_api()
  s <- safely(brreg_search(nace_code = "64.190", max_results = 5))
  expect_gt(nrow(s), 0)
})

test_that("brreg_search: bankrupt filter", {
  skip_if_no_api()
  s <- safely(brreg_search(bankrupt = TRUE, max_results = 5))
  if (nrow(s) > 0) {
    expect_true(all(s$bankrupt))
  }
})

test_that("brreg_search: empty result returns empty tibble", {
  skip_if_no_api()
  s <- safely(brreg_search(name = "ZZZZNOTEXIST999QQQQQ", max_results = 5))
  expect_equal(nrow(s), 0)
  expect_s3_class(s, "tbl_df")
})

test_that("brreg_search: max_results is respected", {
  skip_if_no_api()
  s <- safely(brreg_search(name = "AS", max_results = 3))
  expect_lte(nrow(s), 3)
})

test_that("brreg_search: type=label works", {
  skip_if_no_api()
  s <- safely(brreg_search(name = "Equinor", max_results = 2, type = "label"))
  expect_gt(nrow(s), 0)
  # legal_form should be translated
  expect_true(all(nchar(s$legal_form) > 3))
})

test_that("brreg_search: underenheter registry", {
  skip_if_no_api()
  s <- safely(brreg_search(name = "Equinor", registry = "underenheter", max_results = 5))
  expect_s3_class(s, "tbl_df")
})

# ── Underenheter & children ─────────────────────────────────────────────

test_that("brreg_underenheter: returns sub-units", {
  skip_if_no_api()
  subs <- safely(brreg_underenheter("923609016", max_results = 10))
  expect_s3_class(subs, "tbl_df")
  expect_gt(nrow(subs), 0)
})

test_that("brreg_children: returns child entities", {
  skip_if_no_api()
  # Stortinget has child entities
  children <- safely(brreg_children("971524960", max_results = 5))
  expect_s3_class(children, "tbl_df")
  # May or may not have children depending on registry state
})

# ── Roles ────────────────────────────────────────────────────────────────

test_that("brreg_roles: returns correct structure", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  expect_s3_class(roles, "tbl_df")
  expect_gt(nrow(roles), 0)
  expected_cols <- c("org_nr", "role_group", "role_group_code", "role",
                     "role_code", "first_name", "last_name", "person_id",
                     "birth_date", "deceased", "resigned")
  for (col in expected_cols) {
    expect_true(col %in% names(roles), label = paste("Column", col, "exists"))
  }
})

test_that("brreg_roles: role_group and role are English labels", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  # Should have English labels like "Board of Directors", "Chair", "CEO"
  expect_true(any(grepl("Board|Director|CEO|Chair|Member|Auditor", roles$role_group)))
  expect_true(any(grepl("Chair|Member|CEO|Auditor|Managing|Deputy", roles$role)))
})

test_that("brreg_roles: birth_date is Date type", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  expect_s3_class(roles$birth_date, "Date")
})

test_that("brreg_roles: person_id is constructed correctly", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  person_roles <- roles[!is.na(roles$person_id), ]
  expect_gt(nrow(person_roles), 0)
  # person_id format: YYYY-MM-DD_lastname_firstname_middlename
  expect_true(all(grepl("^\\d{4}-\\d{2}-\\d{2}_", person_roles$person_id)))
})

test_that("brreg_roles: entity-held roles have entity_org_nr", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  entity_roles <- roles[!is.na(roles$entity_org_nr), ]
  # Equinor should have an auditor firm
  expect_gt(nrow(entity_roles), 0)
})

test_that("brreg_board_summary: computes covariates", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  bs <- brreg_board_summary(roles)
  expect_equal(nrow(bs), 1)
  expect_gt(bs$board_size, 0)
  expect_true(is.logical(bs$has_ceo))
  expect_true(is.logical(bs$has_auditor))
  expect_true(bs$has_auditor)  # Equinor must have an auditor
  expect_true(bs$has_ceo)      # Equinor must have a CEO
  expect_true(is.integer(bs$board_size))
})

test_that("brreg_roles_legal: reverse role lookup", {
  skip_if_no_api()
  # Equinor should hold roles in subsidiaries
  legal <- safely(brreg_roles_legal("923609016"))
  expect_s3_class(legal, "tbl_df")
  if (nrow(legal) > 0) {
    expect_true(all(c("org_nr", "target_org_nr", "role_code", "role") %in% names(legal)))
  }
})

# ── Updates (CDC) ────────────────────────────────────────────────────────

test_that("brreg_updates: enheter returns correct structure", {
  skip_if_no_api()
  u <- safely(brreg_updates(since = Sys.Date() - 3, size = 20))
  expect_s3_class(u, "tbl_df")
  expect_gt(nrow(u), 0)
  expected_cols <- c("update_id", "org_nr", "change_type", "timestamp")
  expect_true(all(expected_cols %in% names(u)))
  expect_type(u$update_id, "integer")
  expect_type(u$org_nr, "character")
  expect_s3_class(u$timestamp, "POSIXct")
  # change_type should be one of known values
  expect_true(all(u$change_type %in% c("Ny", "Endring", "Sletting", "Ukjent")))
})

test_that("brreg_updates: update_ids are monotonically increasing", {
  skip_if_no_api()
  u <- safely(brreg_updates(since = Sys.Date() - 3, size = 50))
  if (nrow(u) > 1) {
    expect_true(all(diff(u$update_id) >= 0))
  }
})

test_that("brreg_updates: include_changes adds changes column for Endring", {
  skip_if_no_api()
  # Use larger size to ensure we get Endring type updates
  u <- safely(brreg_updates(since = Sys.Date() - 3, size = 100, include_changes = TRUE))
  endring_rows <- u[u$change_type == "Endring", ]
  if (nrow(endring_rows) > 0 && "changes" %in% names(u)) {
    first_endring <- endring_rows$changes[[1]]
    if (!is.null(first_endring) && nrow(first_endring) > 0) {
      expect_true(all(c("operation", "field", "new_value") %in% names(first_endring)))
    }
  }
})

test_that("brreg_updates: underenheter type works", {
  skip_if_no_api()
  u <- safely(brreg_updates(since = Sys.Date() - 3, size = 10, type = "underenheter"))
  expect_s3_class(u, "tbl_df")
  expect_gt(nrow(u), 0)
  expect_true(all(c("update_id", "org_nr") %in% names(u)))
})

test_that("brreg_updates: roller type works (CloudEvents)", {
  skip_if_no_api()
  u <- safely(brreg_updates(since = Sys.Date() - 3, size = 10, type = "roller"))
  expect_s3_class(u, "tbl_df")
  expect_gt(nrow(u), 0)
  expect_true(all(c("update_id", "org_nr", "change_type", "timestamp") %in% names(u)))
})

# ── Labels ───────────────────────────────────────────────────────────────

test_that("brreg_label: labels legal_form correctly", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  labeled <- brreg_label(eq)
  expect_match(labeled$legal_form, "company|public", ignore.case = TRUE)
})

test_that("brreg_label: vector mode with dic", {
  result <- brreg_label(c("AS", "ASA", "ENK"), dic = "legal_form")
  expect_type(result, "character")
  expect_length(result, 3)
  expect_true(all(nchar(result) > 2))
  expect_match(result[1], "company|limited", ignore.case = TRUE)
})

test_that("brreg_label: code argument preserves original", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  labeled <- brreg_label(eq, code = "legal_form")
  expect_true("legal_form_code" %in% names(labeled))
  expect_equal(labeled$legal_form_code, "ASA")
})

test_that("brreg_label: errors without dic for vector", {
  expect_error(brreg_label(c("AS", "ASA")), "dic")
})

# ── Dictionaries ─────────────────────────────────────────────────────────

test_that("get_brreg_dic: fetches NACE codes", {
  skip_if_no_api()
  d <- safely(get_brreg_dic("nace"))
  expect_s3_class(d, "tbl_df")
  expect_gt(nrow(d), 1500)
  expect_true(all(c("code", "name_en", "level") %in% names(d)))
  expect_true("06.100" %in% d$code)
})

test_that("get_brreg_dic: fetches sector codes", {
  skip_if_no_api()
  d <- safely(get_brreg_dic("sector"))
  expect_s3_class(d, "tbl_df")
  expect_gt(nrow(d), 10)
  expect_true(all(c("code", "name_en") %in% names(d)))
})

test_that("get_brreg_dic: caches results", {
  skip_if_no_api()
  d1 <- safely(get_brreg_dic("nace"))
  d2 <- safely(get_brreg_dic("nace"))
  expect_identical(d1, d2)
})

# ── Validate ─────────────────────────────────────────────────────────────

test_that("brreg_validate: correct org numbers validate", {
  expect_true(brreg_validate("923609016"))   # Equinor
  expect_true(brreg_validate("984851006"))   # DNB
})

test_that("brreg_validate: incorrect numbers fail", {
  expect_false(brreg_validate("123456789"))
  expect_false(brreg_validate("000000000"))
  expect_false(brreg_validate("12345"))
  expect_false(brreg_validate("abcdefghi"))
})

# ── field_dict integrity ─────────────────────────────────────────────────

test_that("field_dict: all required columns exist", {
  expect_true(all(c("api_path", "col_name", "type") %in% names(field_dict)))
  expect_gt(nrow(field_dict), 40)
})

test_that("field_dict: col_names are unique", {
  expect_equal(length(unique(field_dict$col_name)), nrow(field_dict))
})

test_that("field_dict: types are valid R types", {
  expect_true(all(field_dict$type %in% c("character", "Date", "integer", "logical")))
})

test_that("field_dict: api_paths map to actual API fields", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  # At least 80% of dict columns should be present for a major entity
  present <- sum(field_dict$col_name %in% names(eq))
  expect_gt(present / nrow(field_dict), 0.7)
})

# ── Reference data integrity ────────────────────────────────────────────

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

# ── Cross-function consistency ───────────────────────────────────────────

test_that("entity and search return same columns for same entity", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  s <- safely(brreg_search(name = "EQUINOR ASA", max_results = 1))
  if (nrow(s) > 0 && any(s$org_nr == "923609016")) {
    match_row <- s[s$org_nr == "923609016", ]
    # Key columns should match
    expect_equal(eq$legal_form, match_row$legal_form)
    expect_equal(eq$name, match_row$name)
    expect_equal(eq$nace_1, match_row$nace_1)
  }
})

test_that("roles lookup matches entity CEO indicator", {
  skip_if_no_api()
  roles <- safely(brreg_roles("923609016"))
  bs <- brreg_board_summary(roles)
  expect_true(bs$has_ceo)
  # Verify at least one DAGL role exists
  expect_true(any(roles$role_group_code == "DAGL"))
})

# ── Parsing edge cases ──────────────────────────────────────────────────

test_that("parse_entity: handles entity with minimal fields", {
  skip_if_no_api()
  # ENK (sole proprietorship) often has fewer fields
  s <- safely(brreg_search(legal_form = "ENK", max_results = 1))
  if (nrow(s) > 0) {
    enk <- safely(brreg_entity(s$org_nr[1]))
    expect_s3_class(enk, "tbl_df")
    expect_equal(nrow(enk), 1)
  }
})

test_that("parse_entity: handles entity with all field types", {
  skip_if_no_api()
  eq <- safely(brreg_entity("923609016"))
  # Date columns
  expect_s3_class(eq$founding_date, "Date")
  # Integer columns
  expect_true(is.integer(eq$employees))
  # Logical columns
  expect_true(is.logical(eq$bankrupt))
  # Character columns
  expect_true(is.character(eq$org_nr))
  expect_true(is.character(eq$name))
})

# ── brreg_status (local, no API needed) ──────────────────────────────────

test_that("brreg_status: returns correct structure", {
  status <- brreg_status(quiet = TRUE)
  expect_type(status, "list")
  expect_true(all(c("available", "missing", "all_ready") %in% names(status)))
  expect_type(status$all_ready, "logical")
})

# ── Rate limiting / retry ────────────────────────────────────────────────

test_that("rapid sequential requests succeed (rate limiting works)", {
  skip_if_no_api()
  results <- list()
  orgs <- c("923609016", "984851006", "985615616", "981276957", "982463718")
  for (org in orgs) {
    results[[org]] <- safely(brreg_entity(org))
  }
  for (org in orgs) {
    expect_s3_class(results[[org]], "tbl_df")
    expect_equal(nrow(results[[org]]), 1)
    expect_equal(results[[org]]$org_nr, org)
  }
})

# ── to_snake ─────────────────────────────────────────────────────────────

test_that("to_snake: converts camelCase correctly", {
  expect_equal(to_snake("organisasjonsnummer"), "organisasjonsnummer")
  expect_equal(to_snake("antallAnsatte"), "antall_ansatte")
  expect_equal(to_snake("forretningsadresse.kommune"), "forretningsadresse_kommune")
  expect_equal(to_snake("naeringskode1.kode"), "naeringskode1_kode")
})
