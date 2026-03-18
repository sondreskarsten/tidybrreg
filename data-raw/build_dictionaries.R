## data-raw/build_dictionaries.R
## Run this script to regenerate all bundled reference datasets from live sources.
## Products: field_dict, legal_forms, role_types, role_groups, nace_codes, sector_codes

library(httr2)
library(tibble)
library(dplyr, warn.conflicts = FALSE)
library(purrr)

# =============================================================================
# 1. FIELD DICTIONARY: maps brreg API JSON paths to English column names
#    Unmapped fields pass through with auto snake_case names.
# =============================================================================

field_dict <- tribble(
  ~api_path,                                         ~col_name,                  ~type,
  "organisasjonsnummer",                             "org_nr",                    "character",
  "navn",                                            "name",                      "character",
  "organisasjonsform.kode",                          "legal_form",                "character",
  "organisasjonsform.beskrivelse",                   "legal_form_desc",           "character",
  "stiftelsesdato",                                  "founding_date",             "Date",
  "registreringsdatoEnhetsregisteret",               "registration_date",         "Date",
  "antallAnsatte",                                   "employees",                 "integer",
  "harRegistrertAntallAnsatte",                      "employees_reported",        "logical",
  "hjemmeside",                                      "website",                   "character",
  "naeringskode1.kode",                              "nace_1",                    "character",
  "naeringskode1.beskrivelse",                       "nace_1_desc",               "character",
  "naeringskode2.kode",                              "nace_2",                    "character",
  "naeringskode2.beskrivelse",                       "nace_2_desc",               "character",
  "naeringskode3.kode",                              "nace_3",                    "character",
  "naeringskode3.beskrivelse",                       "nace_3_desc",               "character",
  "institusjonellSektorkode.kode",                   "sector_code",               "character",
  "institusjonellSektorkode.beskrivelse",            "sector_desc",               "character",
  "forretningsadresse.adresse",                      "business_address",          "character",
  "forretningsadresse.postnummer",                   "business_postcode",         "character",
  "forretningsadresse.poststed",                     "business_city",             "character",
  "forretningsadresse.kommunenummer",                "municipality_code",         "character",
  "forretningsadresse.kommune",                      "municipality",              "character",
  "forretningsadresse.landkode",                     "country_code",              "character",
  "forretningsadresse.land",                         "country",                   "character",
  "beliggenhetsadresse.adresse",                     "business_address",          "character",
  "beliggenhetsadresse.postnummer",                  "business_postcode",         "character",
  "beliggenhetsadresse.poststed",                    "business_city",             "character",
  "beliggenhetsadresse.kommunenummer",               "municipality_code",         "character",
  "beliggenhetsadresse.kommune",                     "municipality",              "character",
  "beliggenhetsadresse.landkode",                    "country_code",              "character",
  "beliggenhetsadresse.land",                        "country",                   "character",
  "postadresse.adresse",                             "postal_address",            "character",
  "postadresse.postnummer",                          "postal_postcode",           "character",
  "postadresse.poststed",                            "postal_city",               "character",
  "postadresse.kommunenummer",                       "postal_municipality_code",  "character",
  "postadresse.kommune",                             "postal_municipality",       "character",
  "postadresse.landkode",                            "postal_country_code",       "character",
  "konkurs",                                         "bankrupt",                  "logical",
  "konkursdato",                                     "bankruptcy_date",           "Date",
  "underAvvikling",                                  "in_liquidation",            "logical",
  "underAvviklingDato",                              "liquidation_date",          "Date",
  "underTvangsavviklingEllerTvangsopplosning",       "forced_dissolution",        "logical",
  "registrertIMvaregisteret",                        "vat_registered",            "logical",
  "registreringsdatoMerverdiavgiftsregisteret",      "vat_registration_date",     "Date",
  "registrertIForetaksregisteret",                   "in_business_register",      "logical",
  "registreringsdatoForetaksregisteret",             "business_register_date",    "Date",
  "registrertIFrivillighetsregisteret",              "in_nonprofit_register",     "logical",
  "registreringsdatoFrivillighetsregisteret",        "nonprofit_register_date",   "Date",
  "registrertIStiftelsesregisteret",                 "in_foundation_register",    "logical",
  "overordnetEnhet",                                 "parent_org_nr",             "character",
  "erIKonsern",                                      "in_corporate_group",        "logical",
  "vedtektsfestetFormaal",                           "purpose",                   "character",
  "vedtektsdato",                                    "articles_date",             "Date",
  "sisteInnsendteAarsregnskap",                      "last_annual_accounts",      "integer",
  "maalform",                                        "language_form",             "character",
  "aktivitet",                                       "activity",                  "character"
)


# =============================================================================
# 2. LEGAL FORMS: from brreg /organisasjonsformer + manual English translations
# =============================================================================

resp <- request("https://data.brreg.no/enhetsregisteret/api/organisasjonsformer") |>
  req_user_agent("brreg-r/data-raw") |>
  req_headers(Accept = "application/json") |>
  req_perform()
raw <- resp_body_json(resp)

legal_forms <- map_dfr(raw[["_embedded"]][["organisasjonsformer"]], \(x) tibble(
  code = x$kode, name_no = x$beskrivelse, expired = x$utgaatt %||% NA_character_
))

en_map <- c(
  AS = "Private limited company", ASA = "Public limited company",
  ENK = "Sole proprietorship", ANS = "General partnership (joint liability)",
  DA = "General partnership (shared liability)", KS = "Limited partnership",
  NUF = "Norwegian-registered foreign entity", BA = "Company with limited liability",
  SA = "Cooperative", STI = "Foundation", FLI = "Association / club",
  SPA = "Savings bank", SF = "State enterprise", BBL = "Housing cooperative association",
  BRL = "Housing cooperative", PK = "Pension fund", IKS = "Inter-municipal company",
  KF = "Municipal enterprise", FKF = "County municipal enterprise",
  GFS = "Mutual insurance company", SE = "European company (SE)",
  KOMM = "Municipality", FYLK = "County authority", STAT = "The State",
  ORGL = "Organizational unit (public)", ADOS = "Administrative unit (public)",
  KBO = "Bankruptcy estate", BO = "Other estate", SAM = "Joint ownership (real property)",
  ESEK = "Sectional ownership", PRE = "Shipping partnership",
  ANNA = "Other legal person", BEDR = "Establishment (business sub-unit)",
  AAFY = "Establishment (non-business sub-unit)",
  OPMV = "Split VAT entity", KIRK = "Church of Norway",
  PERS = "Individual in associated register", IKJP = "Other non-legal person",
  KTRF = "Office partnership", EOFG = "European economic interest grouping",
  VPFO = "Securities fund", EOEFG = "European economic interest grouping (alt)",
  SER = "European cooperative society"
)
legal_forms$name_en <- en_map[legal_forms$code]
legal_forms$name_en[is.na(legal_forms$name_en)] <- legal_forms$name_no[is.na(legal_forms$name_en)]

cat("Legal forms:", nrow(legal_forms), "entries,",
    sum(!is.na(legal_forms$name_en) & legal_forms$name_en != legal_forms$name_no), "translated\n")


# =============================================================================
# 3. ROLE TYPES AND GROUPS: manual English (no API source for translations)
# =============================================================================

role_types <- tribble(
  ~code, ~name_en,                          ~name_no,
  "LEDE", "Chair of the Board",             "Styrets leder",
  "NEST", "Deputy Chair",                   "Nestleder",
  "MEDL", "Board Member",                   "Styremedlem",
  "VARA", "Alternate Board Member",         "Varamedlem",
  "OBS",  "Observer",                       "Observatør",
  "DAGL", "CEO / Managing Director",        "Daglig leder",
  "INNH", "Sole Proprietor",               "Innehaver",
  "REVI", "Auditor",                        "Revisor",
  "REGN", "Accountant",                     "Regnskapsfører",
  "KONT", "Contact Person",                 "Kontaktperson",
  "DTPR", "Partner (full liability)",       "Deltaker med proratarisk ansvar",
  "DTSO", "Partner (limited liability)",    "Deltaker med solidarisk ansvar",
  "BEST", "Managing Shipowner",             "Bestyrende reder",
  "BOBE", "Bankruptcy Trustee",             "Bostyrer",
  "KOMP", "General Partner (KS)",           "Komplementar",
  "REPR", "Norwegian Representative",       "Norsk representant",
  "FFØR", "Bookkeeper",                     "Forretningsfører",
  "SAM",  "Co-owner",                       "Sameier"
)

role_groups <- tribble(
  ~code,  ~name_en,                    ~name_no,
  "STYR", "Board of Directors",        "Styre",
  "DAGL", "Management",                "Daglig leder/adm.dir",
  "REVI", "Auditor",                   "Revisor",
  "REGN", "Accountant",                "Regnskapsfører",
  "EIKM", "Owner Municipalities",      "Eierkommuner",
  "KOMP", "General Partners",          "Komplementarer",
  "DTPR", "Partners (full liability)", "Deltakere med proratarisk ansvar",
  "DTSO", "Partners (limited)",        "Deltakere med solidarisk ansvar",
  "INNH", "Proprietor",                "Innehaver",
  "KONT", "Contact",                   "Kontaktperson",
  "BEST", "Managing Shipowner",        "Bestyrende reder",
  "BOBE", "Bankruptcy Trustee",        "Bostyrer",
  "FFØR", "Bookkeeper",               "Forretningsfører",
  "SAM",  "Co-owners",                 "Sameiere",
  "HLSE", "Health/Environment/Safety", "Helse, miljø og sikkerhet"
)


# =============================================================================
# 4. NACE CODES: from SSB Klass API (English, current classification)
# =============================================================================

fetch_klass_en <- function(classification_id, date = Sys.Date()) {
  resp <- request("https://data.ssb.no/api/klass/v1") |>
    req_url_path_append("classifications", classification_id, "codesAt") |>
    req_url_query(date = format(date, "%Y-%m-%d"), language = "en") |>
    req_headers(Accept = "application/json") |>
    req_perform()
  body <- resp_body_json(resp)
  map_dfr(body$codes, \(c) tibble(code = c$code, name_en = c$name, level = c$level))
}

nace_codes <- fetch_klass_en(6)
cat("NACE codes (SN2007, English):", nrow(nace_codes), "entries\n")

sector_codes <- fetch_klass_en(39)
cat("Institutional sector codes:", nrow(sector_codes), "entries\n")


# =============================================================================
# 5. SAVE ALL
# =============================================================================

usethis_available <- requireNamespace("usethis", quietly = TRUE)

save(field_dict, legal_forms, role_types, role_groups,
     nace_codes, sector_codes,
     file = "/home/claude/brreg/R/sysdata.rda", compress = "xz")
cat("Saved sysdata.rda:",
    round(file.size("/home/claude/brreg/R/sysdata.rda") / 1024, 1), "KB\n")

save(legal_forms, file = "/home/claude/brreg/data/legal_forms.rda", compress = "xz")
save(role_types, file = "/home/claude/brreg/data/role_types.rda", compress = "xz")
save(role_groups, file = "/home/claude/brreg/data/role_groups.rda", compress = "xz")
save(field_dict, file = "/home/claude/brreg/data/field_dict.rda", compress = "xz")

cat("\nExported datasets:\n")
cat("  legal_forms:", nrow(legal_forms), "x", ncol(legal_forms), "\n")
cat("  role_types:", nrow(role_types), "x", ncol(role_types), "\n")
cat("  role_groups:", nrow(role_groups), "x", ncol(role_groups), "\n")
cat("  field_dict:", nrow(field_dict), "x", ncol(field_dict), "\n")
cat("  nace_codes:", nrow(nace_codes), "x", ncol(nace_codes), "\n")
cat("  sector_codes:", nrow(sector_codes), "x", ncol(sector_codes), "\n")
