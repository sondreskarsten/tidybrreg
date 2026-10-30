## data-raw/build_dictionaries.R
## Run this script to regenerate all bundled reference datasets from live sources.
## Products: field_dict, legal_forms, role_types, role_groups, nace_codes, sector_codes,
##           regnskap_dict, regnskap_groups, regnskap_items

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
  "postadresse.adresse",                             "postal_address",            "character",
  "postadresse.postnummer",                          "postal_postcode",           "character",
  "postadresse.poststed",                            "postal_city",               "character",
  "postadresse.kommunenummer",                       "postal_municipality_code",  "character",
  "postadresse.kommune",                             "postal_municipality",       "character",
  "postadresse.landkode",                            "postal_country_code",       "character",
  "postadresse.land",                                "postal_country",            "character",
  "beliggenhetsadresse.adresse",                     "location_address",          "character",
  "beliggenhetsadresse.postnummer",                  "location_postcode",         "character",
  "beliggenhetsadresse.poststed",                    "location_city",             "character",
  "beliggenhetsadresse.kommunenummer",               "location_municipality_code","character",
  "beliggenhetsadresse.kommune",                     "location_municipality",     "character",
  "beliggenhetsadresse.landkode",                    "location_country_code",     "character",
  "beliggenhetsadresse.land",                        "location_country",          "character",
  "utenlandskRegisterAdresse.adresse",               "foreign_reg_address",       "character",
  "utenlandskRegisterAdresse.land",                  "foreign_reg_country",       "character",
  "utenlandskRegisterAdresse.poststed",              "foreign_reg_city",          "character",
  "konkurs",                                         "bankrupt",                  "logical",
  "konkursdato",                                     "bankruptcy_date",           "Date",
  "underAvvikling",                                  "in_liquidation",            "logical",
  "underAvviklingDato",                              "liquidation_date",          "Date",
  "underTvangsavviklingEllerTvangsopplosning",       "forced_dissolution",        "logical",
  "tvangsavvikletPgaManglendeSlettingDato",          "forced_dissolution_deletion_date", "Date",
  "tvangsopplostPgaMangelfulltStyreDato",            "forced_dissolution_board_date", "Date",
  "tvangsopplostPgaManglendeRegnskapDato",           "forced_dissolution_accounts_date", "Date",
  "tvangsopplostPgaManglendeRevisorDato",            "forced_dissolution_auditor_date", "Date",
  "registrertIMvaregisteret",                        "vat_registered",            "logical",
  "registreringsdatoMerverdiavgiftsregisteret",      "vat_registration_date",     "Date",
  "registreringsdatoFrivilligMerverdiavgiftsregisteret", "voluntary_vat_reg_date", "Date",
  "frivilligMvaRegistrertBeskrivelser",              "voluntary_vat_descriptions", "character",
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
  "aktivitet",                                       "activity",                  "character",
  "slettedato",                                      "deletion_date",             "Date",
  "nedleggelsesdato",                                "closure_date",              "Date",
  "datoEierskifte",                                  "ownership_change_date",     "Date",
  "fravalgRevisjonDato",                             "audit_exemption_date",      "Date",
  "fravalgRevisjonBeslutningsDato",                  "audit_exemption_decision_date", "Date",
  "registreringsdatoMerverdiavgiftsregisteretEnhetsregisteret", "vat_reg_date_er", "Date",
  "registreringsdatoAntallAnsatteEnhetsregisteret",  "employee_reg_date_er",      "Date",
  "registreringsdatoAntallAnsatteNavAaregisteret",   "employee_reg_date_nav",     "Date",
  "registreringsdatoAntallAnsatteNAVAaregisteret",   "employee_reg_date_nav",     "Date",
  "registreringsdatoIEnhetsregisteret",              "registration_date",         "Date",
  "oppstartsdato",                                   "start_date",               "Date",
  "registrertIPartiregisteret",                      "in_party_register",         "logical",
  "registreringsdatoPartiregisteret",                "party_register_date",       "Date",
  "telefon",                                         "phone",                     "character",
  "mobil",                                           "mobile",                    "character",
  "epostadresse",                                    "email",                     "character",
  "kapital.belop",                                   "capital_amount",            "numeric",
  "kapital.antallAksjer",                            "capital_shares",            "numeric",
  "kapital.valuta",                                  "capital_currency",          "character",
  "kapital.type",                                    "capital_type",              "character",
  "kapital.innfortDato",                             "capital_date",              "Date",
  "kapital.fulltInnbetalt",                          "capital_fully_paid",        "logical",
  "kapital.innbetalt",                               "capital_paid_in",           "numeric",
  "kapital.bundet",                                  "capital_restricted",        "numeric",
  "hjelpeenhetskode.kode",                           "auxiliary_unit_code",       "character",
  "hjelpeenhetskode.beskrivelse",                    "auxiliary_unit_desc",       "character",
  "paategninger",                                    "annotations",               "character",
  "utenlandskRegisterNavn",                          "foreign_register_name",     "character",
  "registreringsnummerIHjemlandet",                  "foreign_registration_number", "character",
  "underlagtLovgivningLand",                         "foreign_law_country",       "character",
  "underlagtLovgivningLandKode",                     "foreign_law_country_code",  "character",
  "foretaksformIHjemlandet.kode",                    "foreign_legal_form",        "character",
  "foretaksformIHjemlandet.beskrivelse",             "foreign_legal_form_desc",   "character",
  "foretaksformIHjemlandet.beskrivelseBokmaal",      "foreign_legal_form_desc_bm", "character",
  "underRekonstruksjonsforhandlingDato",             "reconstruction_date",       "Date",
  "underUtenlandskInsolvensbehandlingDato",          "foreign_insolvency_date",   "Date",
  "respons_klasse",                                  "response_class",            "character"
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
  "OBS",  "Observer",                       "Observat\u00f8r",
  "DAGL", "CEO / Managing Director",        "Daglig leder",
  "INNH", "Sole Proprietor",               "Innehaver",
  "REVI", "Auditor",                        "Revisor",
  "REGN", "Accountant",                     "Regnskapsf\u00f8rer",
  "KONT", "Contact Person",                 "Kontaktperson",
  "DTPR", "Partner (full liability)",       "Deltaker med proratarisk ansvar",
  "DTSO", "Partner (limited liability)",    "Deltaker med solidarisk ansvar",
  "BEST", "Managing Shipowner",             "Bestyrende reder",
  "BOBE", "Bankruptcy Trustee",             "Bostyrer",
  "KOMP", "General Partner (KS)",           "Komplementar",
  "REPR", "Norwegian Representative",       "Norsk representant",
  "FF\u00d8R", "Bookkeeper",                     "Forretningsf\u00f8rer",
  "SAM",  "Co-owner",                       "Sameier",
  "SIGN", "Signature Right",                "Signatur",
  "SIFE", "Signature Right (Jointly)",      "Signatur i fellesskap",
  "SIHV", "Signature Right (Separately)",   "Signatur hver for seg",
  "PROK", "Power of Procuration",           "Prokura",
  "POFE", "Power of Procuration (Jointly)", "Prokura i fellesskap",
  "POHV", "Power of Procuration (Separately)", "Prokura hver for seg"
)

role_groups <- tribble(
  ~code,  ~name_en,                    ~name_no,
  "STYR", "Board of Directors",        "Styre",
  "DAGL", "Management",                "Daglig leder/adm.dir",
  "REVI", "Auditor",                   "Revisor",
  "REGN", "Accountant",                "Regnskapsf\u00f8rer",
  "EIKM", "Owner Municipalities",      "Eierkommuner",
  "KOMP", "General Partners",          "Komplementarer",
  "DTPR", "Partners (full liability)", "Deltakere med proratarisk ansvar",
  "DTSO", "Partners (limited)",        "Deltakere med solidarisk ansvar",
  "INNH", "Proprietor",                "Innehaver",
  "KONT", "Contact",                   "Kontaktperson",
  "BEST", "Managing Shipowner",        "Bestyrende reder",
  "BOBE", "Bankruptcy Trustee",        "Bostyrer",
  "FF\u00d8R", "Bookkeeper",               "Forretningsf\u00f8rer",
  "SAM",  "Co-owners",                 "Sameiere",
  "HLSE", "Health/Environment/Safety", "Helse, milj\u00f8 og sikkerhet"
)

annotation_infotypes <- tribble(
  ~code,       ~name_en,
  "NAVN",      "Name annotation",
  "FADR",      "Business address presumed incorrect",
  "KONT",      "Missing contact person",
  "DAGL",      "Missing general manager",
  "FF\u00d8R", "Missing business manager",
  "REPR",      "Missing Norwegian representative",
  "SAM",       "Incomplete co-owner information"
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
  out <- map_dfr(body$codes, \(c) tibble(code = as.character(c$code),
                                          name = as.character(c$name),
                                          level = as.character(c$level)))
  attr(out, "vintage") <- date
  attr(out, "classification_id") <- as.integer(classification_id)
  attr(out, "source_url") <- paste0("https://data.ssb.no/api/klass/v1/classifications/",
                                    classification_id, "/codesAt")
  out
}

nace_codes <- fetch_klass_en(6)
cat("NACE codes (SN2007, English):", nrow(nace_codes), "entries\n")

sector_codes <- fetch_klass_en(39)
cat("Institutional sector codes:", nrow(sector_codes), "entries\n")


# =============================================================================
# 6. REGNSKAP DICTIONARIES: the Regnskapsregisteret filing (OpenAPI 1.1.16),
#    written the way field_dict, role_groups and role_types are for
#    entities and roles. regnskap_dict maps dot paths to names and types
#    and names the line items; regnskap_groups names the objects that
#    group line items (level-0 rows are the three statements);
#    regnskap_items carries the English and Norwegian labels of the line
#    items (the Norwegian names are the statutory presentation-plan
#    captions; English is a manual translation). Source spellings such
#    as regnkapsprinsipper and sumInnskuttEgenkaptial are the API's own.
# =============================================================================

regnskap_dict <- tibble::tribble(
  ~api_path, ~col_name, ~type,
  "id", "filing_id", "integer",
  "journalnr", "journal_nr", "character",
  "regnskapstype", "account_type", "character",
  "virksomhet.organisasjonsnummer", "org_nr", "character",
  "virksomhet.organisasjonsform", "legal_form", "character",
  "virksomhet.morselskap", "parent_company", "logical",
  "regnskapsperiode.fraDato", "period_start", "Date",
  "regnskapsperiode.tilDato", "period_end", "Date",
  "valuta", "currency", "character",
  "avviklingsregnskap", "liquidation_accounts", "logical",
  "oppstillingsplan", "presentation_plan", "character",
  "revisjon.ikkeRevidertAarsregnskap", "not_audited", "logical",
  "revisjon.fravalgRevisjon", "audit_waived", "logical",
  "regnkapsprinsipper.smaaForetak", "small_enterprise", "logical",
  "regnkapsprinsipper.regnskapsregler", "accounting_rules", "character",
  "egenkapitalGjeld.sumEgenkapitalGjeld", "total_equity_liabilities", "numeric",
  "egenkapitalGjeld.egenkapital.sumEgenkapital", "total_equity", "numeric",
  "egenkapitalGjeld.egenkapital.innskuttEgenkapital.sumInnskuttEgenkaptial", "paid_in_equity", "numeric",
  "egenkapitalGjeld.egenkapital.opptjentEgenkapital.sumOpptjentEgenkapital", "retained_equity", "numeric",
  "egenkapitalGjeld.gjeldOversikt.sumGjeld", "total_liabilities", "numeric",
  "egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld.sumKortsiktigGjeld", "current_liabilities", "numeric",
  "egenkapitalGjeld.gjeldOversikt.langsiktigGjeld.sumLangsiktigGjeld", "long_term_liabilities", "numeric",
  "eiendeler.sumEiendeler", "total_assets", "numeric",
  "eiendeler.omloepsmidler.sumOmloepsmidler", "current_assets", "numeric",
  "eiendeler.anleggsmidler.sumAnleggsmidler", "fixed_assets", "numeric",
  "eiendeler.sumBankinnskuddOgKontanter", "cash_and_bank", "numeric",
  "eiendeler.sumFordringer", "receivables", "numeric",
  "eiendeler.sumInvesteringer", "investments", "numeric",
  "eiendeler.sumVarer", "inventory", "numeric",
  "eiendeler.goodwill", "goodwill", "numeric",
  "resultatregnskapResultat.aarsresultat", "net_income", "numeric",
  "resultatregnskapResultat.ordinaertResultatFoerSkattekostnad", "pre_tax_income", "numeric",
  "resultatregnskapResultat.totalresultat", "comprehensive_income", "numeric",
  "resultatregnskapResultat.ordinaertResultatSkattekostnad", "tax_expense", "numeric",
  "resultatregnskapResultat.ekstraordinaerePoster", "extraordinary_items", "numeric",
  "resultatregnskapResultat.skattekostnadEkstraordinaertResultat", "extraordinary_tax", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsresultat", "operating_income", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsinntekter.sumDriftsinntekter", "operating_revenue", "numeric",
  "resultatregnskapResultat.driftsresultat.driftsinntekter.salgsinntekter", "sales_revenue", "numeric",
  "resultatregnskapResultat.driftsresultat.driftskostnad.sumDriftskostnad", "operating_expenses", "numeric",
  "resultatregnskapResultat.driftsresultat.driftskostnad.loennskostnad", "payroll_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.nettoFinans", "net_financial_items", "numeric",
  "resultatregnskapResultat.finansresultat.finansinntekt.sumFinansinntekter", "financial_income", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.sumFinanskostnad", "financial_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.annenRentekostnad", "other_interest_expenses", "numeric",
  "resultatregnskapResultat.finansresultat.finanskostnad.rentekostnadSammeKonsern", "intra_group_interest_expenses", "numeric"
)

regnskap_groups <- tibble::tribble(
  ~path, ~group,
  "eiendeler", "assets",
  "eiendeler.omloepsmidler", "current_assets",
  "eiendeler.anleggsmidler", "fixed_assets",
  "egenkapitalGjeld", "equity_liabilities",
  "egenkapitalGjeld.egenkapital", "equity",
  "egenkapitalGjeld.egenkapital.innskuttEgenkapital", "paid_in_equity",
  "egenkapitalGjeld.egenkapital.opptjentEgenkapital", "retained_equity",
  "egenkapitalGjeld.gjeldOversikt", "liabilities",
  "egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld", "current_liabilities",
  "egenkapitalGjeld.gjeldOversikt.langsiktigGjeld", "long_term_liabilities",
  "resultatregnskapResultat", "income_statement",
  "resultatregnskapResultat.driftsresultat", "operating",
  "resultatregnskapResultat.driftsresultat.driftsinntekter", "operating_revenue",
  "resultatregnskapResultat.driftsresultat.driftskostnad", "operating_expenses",
  "resultatregnskapResultat.finansresultat", "financial",
  "resultatregnskapResultat.finansresultat.finansinntekt", "financial_income",
  "resultatregnskapResultat.finansresultat.finanskostnad", "financial_expenses"
)

regnskap_groups <- tribble(
  ~path, ~code, ~name_en, ~name_no,
  "eiendeler", "assets", "Assets", "Eiendeler",
  "eiendeler.omloepsmidler", "current_assets", "Current assets", "Oml\u00f8psmidler",
  "eiendeler.anleggsmidler", "fixed_assets", "Fixed assets", "Anleggsmidler",
  "egenkapitalGjeld", "equity_liabilities", "Equity and liabilities", "Egenkapital og gjeld",
  "egenkapitalGjeld.egenkapital", "equity", "Equity", "Egenkapital",
  "egenkapitalGjeld.egenkapital.innskuttEgenkapital", "paid_in_equity", "Paid-in equity", "Innskutt egenkapital",
  "egenkapitalGjeld.egenkapital.opptjentEgenkapital", "retained_equity", "Retained earnings", "Opptjent egenkapital",
  "egenkapitalGjeld.gjeldOversikt", "liabilities", "Liabilities", "Gjeld",
  "egenkapitalGjeld.gjeldOversikt.kortsiktigGjeld", "current_liabilities", "Current liabilities", "Kortsiktig gjeld",
  "egenkapitalGjeld.gjeldOversikt.langsiktigGjeld", "long_term_liabilities", "Long-term liabilities", "Langsiktig gjeld",
  "resultatregnskapResultat", "income_statement", "Income statement", "Resultatregnskap",
  "resultatregnskapResultat.driftsresultat", "operating", "Operating result", "Driftsresultat",
  "resultatregnskapResultat.driftsresultat.driftsinntekter", "operating_revenue", "Operating revenue", "Driftsinntekter",
  "resultatregnskapResultat.driftsresultat.driftskostnad", "operating_expenses", "Operating expenses", "Driftskostnader",
  "resultatregnskapResultat.finansresultat", "financial", "Financial result", "Finansresultat",
  "resultatregnskapResultat.finansresultat.finansinntekt", "financial_income", "Financial income", "Finansinntekter",
  "resultatregnskapResultat.finansresultat.finanskostnad", "financial_expenses", "Financial expenses", "Finanskostnader"
)

regnskap_items <- tribble(
  ~code, ~name_en, ~name_no,
  "total_equity_liabilities", "Total equity and liabilities", "Sum egenkapital og gjeld",
  "total_equity", "Total equity", "Sum egenkapital",
  "paid_in_equity", "Paid-in equity", "Sum innskutt egenkapital",
  "retained_equity", "Retained earnings", "Sum opptjent egenkapital",
  "total_liabilities", "Total liabilities", "Sum gjeld",
  "current_liabilities", "Current liabilities", "Sum kortsiktig gjeld",
  "long_term_liabilities", "Long-term liabilities", "Sum langsiktig gjeld",
  "total_assets", "Total assets", "Sum eiendeler",
  "current_assets", "Current assets", "Sum oml\u00f8psmidler",
  "fixed_assets", "Fixed assets", "Sum anleggsmidler",
  "cash_and_bank", "Cash and bank deposits", "Sum bankinnskudd og kontanter",
  "receivables", "Receivables", "Sum fordringer",
  "investments", "Investments", "Sum investeringer",
  "inventory", "Inventories", "Sum varer",
  "goodwill", "Goodwill", "Goodwill",
  "net_income", "Net income", "\u00c5rsresultat",
  "pre_tax_income", "Ordinary income before tax", "Ordin\u00e6rt resultat f\u00f8r skattekostnad",
  "comprehensive_income", "Total comprehensive income", "Totalresultat",
  "tax_expense", "Tax on ordinary income", "Skattekostnad p\u00e5 ordin\u00e6rt resultat",
  "extraordinary_items", "Extraordinary items", "Ekstraordin\u00e6re poster",
  "extraordinary_tax", "Tax on extraordinary items", "Skattekostnad p\u00e5 ekstraordin\u00e6rt resultat",
  "operating_income", "Operating income", "Driftsresultat",
  "operating_revenue", "Total operating revenue", "Sum driftsinntekter",
  "sales_revenue", "Sales revenue", "Salgsinntekter",
  "operating_expenses", "Total operating expenses", "Sum driftskostnader",
  "payroll_expenses", "Payroll expenses", "L\u00f8nnskostnad",
  "net_financial_items", "Net financial items", "Netto finans",
  "financial_income", "Total financial income", "Sum finansinntekter",
  "financial_expenses", "Total financial expenses", "Sum finanskostnader",
  "other_interest_expenses", "Other interest expenses", "Annen rentekostnad",
  "intra_group_interest_expenses", "Interest expenses to group companies", "Rentekostnad til foretak i samme konsern"
)


# =============================================================================
# 5. SAVE ALL
# =============================================================================

## Exported datasets ship in data/ and are duplicated into R/sysdata.rda so
## package code can reference them when the namespace is loaded but not
## attached. The KLASS fallbacks are internal only. annotation_infotypes
## belongs to tidybrregpanel.
save(field_dict, file = "data/field_dict.rda", compress = "xz")
save(legal_forms, file = "data/legal_forms.rda", compress = "xz")
save(role_types, file = "data/role_types.rda", compress = "xz")
save(role_groups, file = "data/role_groups.rda", compress = "xz")
save(regnskap_dict, file = "data/regnskap_dict.rda", compress = "xz")
save(regnskap_groups, file = "data/regnskap_groups.rda", compress = "xz")
save(regnskap_items, file = "data/regnskap_items.rda", compress = "xz")
save(annotation_infotypes, file = "tidybrregpanel/data/annotation_infotypes.rda", compress = "xz")
save(field_dict, legal_forms, role_types, role_groups, nace_codes, sector_codes,
     regnskap_dict, regnskap_groups, regnskap_items,
     file = "R/sysdata.rda", compress = "xz")
cat("Saved sysdata.rda:",
    round(file.size("R/sysdata.rda") / 1024, 1), "KB\n")
cat("Record the run date in man/tidybrreg_provenance.Rd (R/tidybrreg-package.R)\n")

cat("\nExported datasets:\n")
cat("  legal_forms:", nrow(legal_forms), "x", ncol(legal_forms), "\n")
cat("  role_types:", nrow(role_types), "x", ncol(role_types), "\n")
cat("  role_groups:", nrow(role_groups), "x", ncol(role_groups), "\n")
cat("  field_dict:", nrow(field_dict), "x", ncol(field_dict), "\n")
cat("  regnskap_dict:", nrow(regnskap_dict), "x", ncol(regnskap_dict), "\n")
cat("  regnskap_groups:", nrow(regnskap_groups), "x", ncol(regnskap_groups), "\n")
cat("  regnskap_items:", nrow(regnskap_items), "x", ncol(regnskap_items), "\n")
cat("  nace_codes:", nrow(nace_codes), "x", ncol(nace_codes), "\n")
cat("  sector_codes:", nrow(sector_codes), "x", ncol(sector_codes), "\n")
