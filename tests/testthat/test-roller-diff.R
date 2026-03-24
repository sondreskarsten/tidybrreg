# --- Helper: minimal test fixture ---

make_test_roles <- function() {
  tibble::tibble(
    org_nr = "111",
    role_group_code = "STYR",
    role_group = "Board",
    role_code = "LEDE",
    role = "Chair",
    first_name = "Jan",
    middle_name = NA_character_,
    last_name = "Aarrestad",
    birth_date = as.Date("1951-07-16"),
    deceased = FALSE,
    entity_org_nr = NA_character_,
    entity_name = NA_character_,
    resigned = FALSE,
    deregistered = FALSE,
    ordering = 0L,
    elected_by = NA_character_,
    group_modified = as.Date("2024-01-01"),
    person_id = "1951-07-16_aarrestad_jan_"
  )
}


test_that("add_role_key derives person-held keys from person_id", {
  df <- tibble::tibble(
    org_nr = "111", role_group_code = "STYR", role_code = "LEDE",
    person_id = "1951-07-16_aarrestad_jan_", entity_org_nr = NA_character_
  )
  result <- tidybrreg:::add_role_key(df)
  expect_equal(result$holder_id, "1951-07-16_aarrestad_jan_")
  expect_equal(result$role_key, "111|STYR|LEDE|1951-07-16_aarrestad_jan_")
})

test_that("add_role_key derives entity-held keys", {
  df <- tibble::tibble(
    org_nr = "222", role_group_code = "REVI", role_code = "REVI",
    person_id = NA_character_, entity_org_nr = "987654321"
  )
  result <- tidybrreg:::add_role_key(df)
  expect_equal(result$holder_id, "entity:987654321")
  expect_equal(result$role_key, "222|REVI|REVI|entity:987654321")
})

test_that("add_role_key falls back to positional key for unknown holders", {
  df <- tibble::tibble(
    org_nr = "333", role_group_code = "STYR", role_code = "MEDL",
    person_id = NA_character_, entity_org_nr = NA_character_
  )
  result <- tidybrreg:::add_role_key(df)
  expect_match(result$holder_id, "^unknown:")
})


# --- diff_roller_state: identical states ---

test_that("diff_roller_state returns empty tibble for identical states", {
  state <- make_test_roles()
  result <- tidybrreg:::diff_roller_state(state, state)
  expect_equal(nrow(result), 0L)
})


# --- diff_roller_state: NULL old state (first run) ---

test_that("diff_roller_state treats NULL old state as all entries", {
  new <- make_test_roles()
  result <- tidybrreg:::diff_roller_state(NULL, new,
    timestamp = "2026-01-01T00:00:00", update_id = 1L)
  expect_true(all(result$change_type == "entry"))
  expect_true(all(result$registry == "roller"))
  expect_true(nrow(result) > 0)
  expect_true(all(!is.na(result$value_to)))
})


# --- diff_roller_state: role addition ---

test_that("diff_roller_state detects added roles", {
  old <- make_test_roles()
  new <- dplyr::bind_rows(old, tibble::tibble(
    org_nr = "111", role_group_code = "STYR", role_group = "Board",
    role_code = "MEDL", role = "Member",
    first_name = "Ola", middle_name = NA_character_,
    last_name = "Nordmann", birth_date = as.Date("1990-01-01"),
    deceased = FALSE, entity_org_nr = NA_character_,
    entity_name = NA_character_, resigned = FALSE,
    deregistered = FALSE, ordering = 2L,
    elected_by = NA_character_, group_modified = as.Date("2026-03-01"),
    person_id = "1990-01-01_nordmann_ola_"
  ))
  result <- tidybrreg:::diff_roller_state(old, new)
  entries <- result[result$change_type == "entry", ]
  expect_true(nrow(entries) > 0)
  expect_true("Ola" %in% entries$value_to)
  expect_true("Nordmann" %in% entries$value_to)
})


# --- diff_roller_state: role removal ---

test_that("diff_roller_state detects removed roles", {
  old <- make_test_roles()
  new <- old[-1, ]
  result <- tidybrreg:::diff_roller_state(old, new)
  exits <- result[result$change_type == "exit", ]
  expect_true(nrow(exits) > 0)
  expect_true(all(!is.na(exits$value_from)))
  expect_true(all(is.na(exits$value_to)))
})


# --- diff_roller_state: field-level modifications ---

test_that("diff_roller_state detects deceased flag change", {
  old <- make_test_roles()
  new <- old
  new$deceased[1] <- TRUE
  result <- tidybrreg:::diff_roller_state(old, new)
  changes <- result[result$change_type == "change", ]
  deceased_row <- changes[changes$field == "deceased", ]
  expect_equal(nrow(deceased_row), 1L)
  expect_equal(deceased_row$value_from, "FALSE")
  expect_equal(deceased_row$value_to, "TRUE")
})

test_that("diff_roller_state detects resigned flag change", {
  old <- make_test_roles()
  new <- old
  new$resigned[1] <- TRUE
  result <- tidybrreg:::diff_roller_state(old, new)
  changes <- result[result$change_type == "change", ]
  resigned_row <- changes[changes$field == "resigned", ]
  expect_equal(nrow(resigned_row), 1L)
  expect_equal(resigned_row$value_from, "FALSE")
  expect_equal(resigned_row$value_to, "TRUE")
})

test_that("diff_roller_state detects elected_by NA to value transition", {
  old <- make_test_roles()
  new <- old
  new$elected_by[1] <- "AREP"
  result <- tidybrreg:::diff_roller_state(old, new)
  changes <- result[result$change_type == "change", ]
  elected_row <- changes[changes$field == "elected_by", ]
  expect_equal(nrow(elected_row), 1L)
  expect_true(is.na(elected_row$value_from))
  expect_equal(elected_row$value_to, "AREP")
})


# --- diff_roller_state: auditor entity swap ---

test_that("diff_roller_state treats auditor entity change as remove + add", {
  old <- tibble::tibble(
    org_nr = "222", role_group_code = "REVI", role_group = "Auditor",
    role_code = "REVI", role = "Auditor",
    first_name = NA_character_, middle_name = NA_character_,
    last_name = NA_character_, birth_date = as.Date(NA),
    deceased = NA, entity_org_nr = "987654321",
    entity_name = "PwC AS", resigned = FALSE,
    deregistered = FALSE, ordering = 0L,
    elected_by = NA_character_, group_modified = as.Date("2024-01-01"),
    person_id = NA_character_
  )
  new <- old
  new$entity_org_nr <- "912345678"
  new$entity_name <- "Deloitte AS"

  result <- tidybrreg:::diff_roller_state(old, new)
  expect_true(any(result$change_type == "exit"))
  expect_true(any(result$change_type == "entry"))
  exits <- result[result$change_type == "exit", ]
  expect_true("987654321" %in% exits$value_from)
  entries <- result[result$change_type == "entry", ]
  expect_true("912345678" %in% entries$value_to)
})


# --- diff_roller_state: changelog schema matches package convention ---

test_that("diff_roller_state output matches changelog schema", {
  old <- make_test_roles()
  new <- old
  new$deceased[1] <- TRUE
  result <- tidybrreg:::diff_roller_state(old, new, timestamp = "2026-03-24", update_id = 42L)
  expected_cols <- c("timestamp", "org_nr", "registry", "change_type",
                     "field", "value_from", "value_to", "update_id")
  expect_equal(sort(names(result)), sort(expected_cols))
  expect_equal(result$update_id[1], 42L)
  expect_equal(result$timestamp[1], "2026-03-24")
  expect_true(all(result$registry == "roller"))
})


# --- diff_roller_state: combined mutations ---

test_that("diff_roller_state handles simultaneous add + remove + modify", {
  old <- dplyr::bind_rows(
    make_test_roles(),
    tibble::tibble(
      org_nr = "111", role_group_code = "STYR", role_group = "Board",
      role_code = "MEDL", role = "Member",
      first_name = "Kari", middle_name = NA_character_,
      last_name = "Berg", birth_date = as.Date("1975-03-10"),
      deceased = FALSE, entity_org_nr = NA_character_,
      entity_name = NA_character_, resigned = FALSE,
      deregistered = FALSE, ordering = 1L,
      elected_by = NA_character_, group_modified = as.Date("2024-01-01"),
      person_id = "1975-03-10_berg_kari_"
    )
  )
  new <- old[-1, ]
  new$deceased[1] <- TRUE
  new <- dplyr::bind_rows(new, tibble::tibble(
    org_nr = "111", role_group_code = "DAGL", role_group = "Management",
    role_code = "DAGL", role = "CEO",
    first_name = "Per", middle_name = NA_character_,
    last_name = "Hansen", birth_date = as.Date("1985-06-15"),
    deceased = FALSE, entity_org_nr = NA_character_,
    entity_name = NA_character_, resigned = FALSE,
    deregistered = FALSE, ordering = 0L,
    elected_by = NA_character_, group_modified = as.Date("2026-03-01"),
    person_id = "1985-06-15_hansen_per_"
  ))

  result <- tidybrreg:::diff_roller_state(old, new)
  types <- unique(result$change_type)
  expect_true("entry" %in% types)
  expect_true("exit" %in% types)
  expect_true("change" %in% types)
})


# --- identical_or_both_na ---

test_that("identical_or_both_na handles all cases", {
  expect_true(tidybrreg:::identical_or_both_na(NA, NA))
  expect_true(tidybrreg:::identical_or_both_na("a", "a"))
  expect_false(tidybrreg:::identical_or_both_na("a", "b"))
  expect_false(tidybrreg:::identical_or_both_na("a", NA))
  expect_false(tidybrreg:::identical_or_both_na(NA, "b"))
})

test_that("identical_or_both_na is vectorised", {
  x <- c("a", NA, "b", NA)
  y <- c("a", NA, "c", "d")
  result <- tidybrreg:::identical_or_both_na(x, y)
  expect_equal(result, c(TRUE, TRUE, FALSE, FALSE))
})


# --- flatten_roles new fields ---

test_that("flatten_roles includes deregistered, ordering, elected_by, group_modified", {
  raw <- list(rollegrupper = list(
    list(
      type = list(kode = "STYR", beskrivelse = "Styre"),
      sistEndret = "2026-01-15",
      roller = list(
        list(
          type = list(kode = "LEDE", beskrivelse = "Styrets leder"),
          person = list(
            fodselsdato = "1970-01-01",
            navn = list(fornavn = "Test", etternavn = "Person"),
            erDoed = FALSE
          ),
          fratraadt = FALSE,
          avregistrert = FALSE,
          rekkefolge = 0L,
          valgtAv = list(kode = "AREP", beskrivelse = "Representant")
        )
      )
    )
  ))

  result <- tidybrreg:::flatten_roles(raw, "999999999")
  expect_true("deregistered" %in% names(result))
  expect_true("ordering" %in% names(result))
  expect_true("elected_by" %in% names(result))
  expect_true("group_modified" %in% names(result))

  expect_equal(result$deregistered, FALSE)
  expect_equal(result$ordering, 0L)
  expect_equal(result$elected_by, "AREP")
  expect_equal(result$group_modified, as.Date("2026-01-15"))
})


# --- brreg_board_summary ---

test_that("brreg_board_summary excludes deregistered roles", {
  roles <- make_test_roles()
  roles$deregistered[1] <- TRUE
  summary <- brreg_board_summary(roles)
  expect_equal(summary$board_size, 0L)
})

test_that("brreg_board_summary excludes resigned roles", {
  roles <- make_test_roles()
  roles$resigned[1] <- TRUE
  summary <- brreg_board_summary(roles)
  expect_equal(summary$board_size, 0L)
})

test_that("brreg_board_summary counts employee_elected", {
  roles <- make_test_roles()
  roles$elected_by[1] <- "AREP"
  summary <- brreg_board_summary(roles)
  expect_equal(summary$n_employee_elected, 1L)
})


# --- backfill_roller_cols (state schema migration) ---

test_that("backfill_roller_cols adds missing columns with correct types", {
  legacy <- tibble::tibble(
    org_nr = "111", role_group_code = "STYR", role_code = "LEDE",
    first_name = "Jan", last_name = "Aarrestad",
    person_id = "1951-07-16_aarrestad_jan_",
    entity_org_nr = NA_character_
  )
  result <- tidybrreg:::backfill_roller_cols(legacy)
  expect_true("deregistered" %in% names(result))
  expect_true("ordering" %in% names(result))
  expect_true("elected_by" %in% names(result))
  expect_true("group_modified" %in% names(result))
  expect_true(is.na(result$deregistered))
  expect_true(is.na(result$ordering))
  expect_true(is.na(result$elected_by))
  expect_true(is.na(result$group_modified))
})

test_that("backfill_roller_cols is idempotent on new state", {
  roles <- make_test_roles()
  before <- roles
  after <- tidybrreg:::backfill_roller_cols(roles)
  expect_equal(names(before), names(after))
  expect_equal(before$deregistered, after$deregistered)
})

test_that("diff_roller_state handles legacy state missing new columns", {
  legacy_old <- tibble::tibble(
    org_nr = "111", role_group_code = "STYR",
    role_group = "Board", role_code = "LEDE", role = "Chair",
    first_name = "Jan", middle_name = NA_character_,
    last_name = "Aarrestad", birth_date = as.Date("1951-07-16"),
    deceased = FALSE, entity_org_nr = NA_character_,
    entity_name = NA_character_, resigned = FALSE,
    person_id = "1951-07-16_aarrestad_jan_"
  )
  new_state <- make_test_roles()
  new_state$deceased[1] <- TRUE

  result <- tidybrreg:::diff_roller_state(legacy_old, new_state)
  changes <- result[result$change_type == "change", ]
  expect_true(any(changes$field == "deceased"))
})

