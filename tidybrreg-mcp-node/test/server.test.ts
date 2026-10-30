import { describe, it, expect, beforeAll } from "vitest";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { loadManifest, type Manifest } from "../src/manifest.js";
import { Http, type Fetcher } from "../src/http.js";
import { callTool, IMPLEMENTATIONS } from "../src/execute.js";
import { parsePatch } from "../src/tools/updates.js";
import { flattenRoles, flattenKonsern, flattenSignatur, flattenRegnskap } from "../src/tools/satellites.js";
import { parseBrregDate, parseBrregInstant, formatSince } from "../src/dates.js";
import { renameFromDict, flattenJson, coerceRows, toSnake } from "../src/parse.js";
import { validateOrgNr } from "../src/tools/common.js";
import { Conditions } from "../src/conditions.js";
import { buildResources } from "../src/server.js";

process.env.TIDYBRREG_OFFLINE = "1";
const m: Manifest = loadManifest(join(process.cwd(), "manifest.json"));
const fixtures = join(process.cwd(), "..", "tests", "testthat", "fixtures");
const tool = (n: string) => m.tools.find((t) => t.name === n)!;

function queue(responses: { status: number; body?: unknown; headers?: Record<string, string> }[]) {
  const urls: string[] = [];
  const fetcher: Fetcher = async (url) => {
    urls.push(url);
    const r = responses.shift();
    if (!r) throw new Error("mock queue exhausted");
    return new Response(r.body === undefined ? null : JSON.stringify(r.body), { status: r.status, headers: { "content-type": "application/json", ...(r.headers ?? {}) } });
  };
  return { http: new Http(m, fetcher), urls };
}

const entity = (org_nr = "923609016", extra: Record<string, unknown> = {}) => ({
  organisasjonsnummer: org_nr, navn: "EQUINOR ASA",
  organisasjonsform: { kode: "ASA", beskrivelse: "Allmennaksjeselskap", _links: { self: { href: "x" } } },
  stiftelsesdato: "1972-09-18", antallAnsatte: 21408, naeringskode1: { kode: "06.100" }, konkurs: false,
  _links: { self: { href: "y" } }, ...extra,
});

describe("manifest and catalogue", () => {
  it("every manifest tool has an implementation and vice versa", () => {
    expect(new Set(m.tools.map((t) => t.name))).toEqual(new Set(Object.keys(IMPLEMENTATIONS)));
    expect(m.tools).toHaveLength(16);
  });
  it("package version matches the manifest's tidybrreg version", () => {
    const pkg = JSON.parse(readFileSync(join(process.cwd(), "package.json"), "utf8"));
    expect(pkg.version).toBe(m.tidybrreg.version);
  });
  it("resources cover docs, dictionaries, endpoints and the manifest", () => {
    const uris = buildResources(m).map((r) => r.uri);
    expect(uris).toContain("tidybrreg://docs/brreg_search");
    expect(uris).toContain("tidybrreg://data/field_dict");
    expect(uris).toContain("tidybrreg://endpoints");
  });
});

describe("pure helpers", () => {
  it("validates org numbers with modulus 11", () => {
    expect(validateOrgNr(m, "923609016")).toBe(true);
    expect(validateOrgNr(m, "984851006")).toBe(true);
    expect(validateOrgNr(m, "123456789")).toBe(false);
    expect(validateOrgNr(m, "984851007")).toBe(false);
  });
  it("parses both BRREG date forms and UTC instants", () => {
    expect(parseBrregDate("24.06.2026")).toBe("2026-06-24");
    expect(parseBrregDate("2026-06-24")).toBe("2026-06-24");
    expect(parseBrregDate("nope")).toBeNull();
    expect(parseBrregInstant("2026-03-15T10:30:00.000Z")).toBe("2026-03-15T10:30:00.000Z");
    expect(parseBrregInstant("2026-03-15")).toBe("2026-03-15T00:00:00.000Z");
    expect(formatSince("2026-03-01T14:00:00Z")).toBe("2026-03-01T14:00:00.000Z");
    expect(formatSince("2026-03-01")).toBe("2026-03-01T00:00:00.000Z");
    expect(() => formatSince("yesterday")).toThrow(/since/);
  });
  it("renames through field_dict, strips HAL, keeps duplicate spellings, coerces", () => {
    const flat = flattenJson(entity("923609016", { registreringsdatoIEnhetsregisteret: "2021-01-01", registreringsdatoEnhetsregisteret: "2020-01-01", fooBar: "a", "foo.bar": "b" }) as any);
    const { row, types } = renameFromDict(m, flat);
    expect(Object.keys(row).some((k) => k.includes("links"))).toBe(false);
    expect(row.legal_form).toBe("ASA");
    expect(row.registration_date).toBe("2020-01-01");
    expect(row.registreringsdato_ienhetsregisteret).toBe("2021-01-01");
    expect(row).toHaveProperty("foo_bar");
    expect(row).toHaveProperty("foo_bar_1");
    const problems = coerceRows([row], types);
    expect(problems).toHaveLength(0);
    expect(row.founding_date).toBe("1972-09-18");
    expect(row.employees).toBe(21408);
    expect(toSnake("registreringsdatoIEnhetsregisteret")).toBe("registreringsdato_ienhetsregisteret");
  });
  it("flattens patches to leaves with raw pointers and move semantics", () => {
    const p = parsePatch([
      { op: "replace", path: "/antallAnsatte", value: 21500 },
      { op: "add", path: "/forretningsadresse", value: { adresse: ["Gate 1", "Inng. 2"], sub: { deep: { leaf: "v" } } } },
      { op: "move", from: "/postadresse/poststed", path: "/forretningsadresse/poststed", value: "OSLO" },
      { op: "remove", path: "/hjemmeside" },
    ]);
    expect(p.find((x) => x.path === "/forretningsadresse/sub/deep/leaf")?.field).toBe("forretningsadresse_sub_deep_leaf");
    expect(p.find((x) => x.path === "/forretningsadresse/adresse/1")?.new_value).toBe("Inng. 2");
    expect(p.filter((x) => x.operation === "remove").map((x) => x.path)).toEqual(expect.arrayContaining(["/postadresse/poststed", "/hjemmeside"]));
  });
});

describe("fixtures shared with the R test suite", () => {
  const ctx = { m, http: new Http(m), cond: new Conditions() };
  it("roles fixture flattens like tidybrreg::brreg_roles", () => {
    const raw = JSON.parse(readFileSync(join(fixtures, "mock", "roles_923609016.json"), "utf8"));
    const rows = flattenRoles(ctx, raw, "923609016");
    expect(rows.length).toBeGreaterThan(5);
    expect(rows[0]).toHaveProperty("person_id");
    expect(rows.some((r) => r.role_group === "Board of Directors")).toBe(true);
    expect(rows.every((r) => !("resigned" in r) || typeof r.resigned === "boolean")).toBe(true);
  });
  it("konsern fixture gives 54 nodes with a synthesized root", () => {
    const raw = JSON.parse(readFileSync(join(fixtures, "konsernstruktur_equinor.json"), "utf8"));
    const rows = flattenKonsern(raw, "923609016");
    expect(rows).toHaveLength(54);
    expect(rows[0].link_form).toBe("KKKK");
    expect(rows.filter((r) => r.level === 1).every((r) => r.link_form === "KDAT")).toBe(true);
  });
  it("signatur birth dates parse DD.MM.YYYY", () => {
    const rows = flattenSignatur(ctx, { enhet: { navn: "X" }, status: { regelStatus: { kode: "RF" } }, signeringsKombinasjon: { kombinasjon: [{ kombinasjonsId: 1, kode: "STYR", tekstforklaring: "Styret", personRolleKombinasjon: [{ navn: "Kari", fodselsdato: "01.01.1970", rolle: { kode: "LEDE" } }] }] } }, "923609016", "signature");
    expect(rows[0].birth_date).toBe("1970-01-01");
    expect(rows[0].role).toBe("Chair of the Board");
  });
});

describe("tools over a mocked register", () => {
  it("brreg_entity nests arrays of objects and joins line fragments like the R package", async () => {
    const body = entity("923609016", {
      vedtektsfestetFormaal: ["Line 1", "Line 2"],
      historiskeNavn: [{ navn: "STATOIL ASA", fraDato: "2001-05-11 08:32:09", tilDato: "2007-10-01 06:44:33" }],
      paategninger: [{ infotype: "KONT", tekst: "x", innfoertDato: "2025-05-05" }, { infotype: "FADR", tekst: "y", innfoertDato: "2025-06-06" }],
      aktivitet: [],
    });
    const q = queue([{ status: 200, body }]);
    const r = await callTool(m, q.http, tool("brreg_entity"), { org_nr: "923609016" });
    expect(r.isError).toBe(false);
    const row = (r.structuredContent.rows as any[])[0];
    expect(row.purpose).toBe("Line 1\nLine 2");
    expect(row.historiske_navn).toEqual([{ navn: "STATOIL ASA", fra_dato: "2001-05-11 08:32:09", til_dato: "2007-10-01 06:44:33" }]);
    expect(row.annotations).toHaveLength(2);
    expect(row.annotations[1]).toEqual({ infotype: "FADR", tekst: "y", innfoert_dato: "2025-06-06" });
    expect("activity" in row).toBe(false);
    expect((r.structuredContent.conditions as any[]).some((c) => c.class === "tidybrreg_warning_parse")).toBe(false);
  });

  it("brreg_entity models deletion and errors like the R package", async () => {
    let q = queue([{ status: 200, body: entity("923609016", { respons_klasse: "SlettetEnhet", slettedato: "2026-02-01" }) }]);
    let r = await callTool(m, q.http, tool("brreg_entity"), { org_nr: "923609016" });
    expect(r.isError).toBe(false);
    const row = (r.structuredContent.rows as any[])[0];
    expect(row.deleted).toBe(true);
    expect(row.deletion_date).toBe("2026-02-01");
    expect((r.structuredContent.conditions as any[])[0].class).toBe("tidybrreg_warning_deleted");
    expect(q.urls[0]).toBe("https://data.brreg.no/enhetsregisteret/api/enheter/923609016");

    q = queue([{ status: 404 }, { status: 404 }]);
    r = await callTool(m, q.http, tool("brreg_entity"), { org_nr: "923609016" });
    expect(r.isError).toBe(true);
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_not_found");
    expect(q.urls[1]).toContain("/underenheter/923609016");

    r = await callTool(m, q.http, tool("brreg_entity"), { org_nr: "123" });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_invalid_org_nr");
    r = await callTool(m, q.http, tool("brreg_entity"), { org_nr: "923609016", registry: "nope" });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_invalid_filter");
  });

  it("brreg_search aborts over the window, flags truncation, and types empties", async () => {
    let q = queue([{ status: 200, body: { page: { totalElements: 57954 }, _embedded: { enheter: [entity()] }, _links: { next: { href: "x" } } } }]);
    let r = await callTool(m, q.http, tool("brreg_search"), { municipality_code: "4601", max_results: 20000 });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_result_window");
    expect((r.structuredContent.error as any).fields.total_matches).toBe(57954);
    expect(q.urls[0]).toContain("kommunenummer=4601");

    q = queue([{ status: 200, body: { page: { totalElements: 57954 }, _embedded: { enheter: [entity(), entity("984851006")] }, _links: { next: { href: "x" } } } }]);
    r = await callTool(m, q.http, tool("brreg_search"), { municipality_code: "4601", max_results: 2 });
    expect(r.isError).toBe(false);
    expect((r.structuredContent.attributes as any).complete).toBe(false);
    expect((r.structuredContent.conditions as any[]).map((c) => c.class)).toContain("tidybrreg_warning_truncated");

    q = queue([{ status: 200, body: { page: { totalElements: 0 } } }]);
    r = await callTool(m, q.http, tool("brreg_search"), { name: "zzz" });
    expect(r.structuredContent.n_total).toBe(0);
    expect((r.structuredContent.columns as any[]).map((c) => c.name)).toEqual(["org_nr", "name", "legal_form"]);

    r = await callTool(m, q.http, tool("brreg_search"), { bankrupt: true, registry: "underenheter" });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_invalid_filter");
  });

  it("satellites follow the 404/410/500 contract", async () => {
    let q = queue([{ status: 404 }]);
    let r = await callTool(m, q.http, tool("brreg_konsern"), { org_nr: "923609016" });
    expect(r.isError).toBe(false);
    expect((r.structuredContent.attributes as any).http_status).toBe(404);
    expect((r.structuredContent.columns as any[]).map((c) => c.name)).toContain("relation_date");
    q = queue([{ status: 410, body: { slettedato: "2026-02-01" } }]);
    r = await callTool(m, q.http, tool("brreg_roles"), { org_nr: "923609016" });
    expect((r.structuredContent.conditions as any[])[0].class).toBe("tidybrreg_warning_deleted");
    q = queue([{ status: 500, body: { error: "boom" } }]);
    r = await callTool(m, q.http, tool("brreg_signatur"), { org_nr: "923609016" });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_http");
    expect((r.structuredContent.error as any).fields.messages).toEqual(["boom"]);
    const unresolved = JSON.parse(readFileSync(join(fixtures, "signatur_unresolved_equinor.json"), "utf8"));
    q = queue([{ status: 200, body: unresolved }]);
    r = await callTool(m, q.http, tool("brreg_signatur"), { org_nr: "923609016" });
    expect(r.isError).toBe(false);
    expect(r.structuredContent.n_total).toBe(0);
    expect((r.structuredContent.attributes as any)).toEqual({ http_status: 200, routine_status: "NA", routine_text: "Generelle unntak, finnes roller som har status det ikke kan foretas maskinelt oppslag mot." });
    expect((r.structuredContent.conditions as any[])[0].class).toBe("tidybrreg_warning_unresolved");
    expect((r.structuredContent.columns as any[]).map((c) => c.name)).toContain("combination_id");
    q = queue([{ status: 400, body: { status: 400, feilmelding: "Feilaktig forespørsel", valideringsfeil: [{ feilmelding: "På grunn av krav til personvern kan du ikke gjøre søk mellom en og fire ansatte", parametere: ["fraAntallAnsatte", "tilAntallAnsatte"] }] } }]);
    r = await callTool(m, q.http, tool("brreg_search"), { min_employees: 1, max_employees: 2 });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_http");
    expect((r.structuredContent.error as any).fields.messages).toEqual(["På grunn av krav til personvern kan du ikke gjøre søk mellom en og fire ansatte (fraAntallAnsatte, tilAntallAnsatte)"]);
  });

  it("regnskap nests one row per filing with items and flags equal to the Python oracle", async () => {
    const fx = JSON.parse(readFileSync(join(fixtures, "regnskap_release_2026-10.json"), "utf8"));
    const expected = JSON.parse(readFileSync(join(fixtures, "regnskap_release_2026-10.expected.json"), "utf8"));
    const spec = m.endpoints.functions.brreg_regnskap;
    const flat = flattenRegnskap(spec, fx, "923609016");
    expect(flat.rows).toHaveLength(expected.length);
    expect(flat.problems).toHaveLength(0);
    flat.rows.forEach((r, i) => {
      expect(r.filing_id).toBe(expected[i].filing_id);
      expect(r.org_nr).toBe(expected[i].org_nr);
      const items = r.items as any[];
      expect(new Set(items.map((x) => x.path))).toEqual(new Set(expected[i].item_paths));
      expect(r.consistent).toBe(expected[i].consistent);
      expect(r.inconsistencies).toEqual(expected[i].inconsistencies);
    });
    expect(Object.keys(flat.rows[0])[0]).toBe("org_nr");
    const all = flat.rows.flatMap((r) => r.items as any[]);
    expect(all.find((x) => x.path === "eiendeler.omloepsmidler.sumOmloepsmidler")).toMatchObject({ statement: "assets", group: "current_assets", item: "current_assets", level: 2, is_sum: true });
    expect(all.find((x) => x.path === "resultatregnskapResultat.aarsresultat")).toMatchObject({ group: "income_statement", item: "net_income", level: 1, is_sum: false });
    expect(all.every((x) => typeof x.value === "number")).toBe(true);
    expect(flat.rows.some((r) => r.consistent === false)).toBe(true);
    for (const f of spec.fields!) if (!/^(eiendeler|egenkapitalGjeld|resultatregnskapResultat)\./.test(f.api_path)) expect(flat.rows[0]).toHaveProperty(f.col_name);

    const f2 = structuredClone(fx[0]); f2.eiendeler.nyPost = 12; f2.nyttFelt = "x"; f2.eiendeler.sumEiendeler = "nope";
    const one = flattenRegnskap(spec, [f2], "923609016");
    expect((one.rows[0].items as any[]).find((x) => x.path === "eiendeler.nyPost")).toMatchObject({ item: "ny_post", group: "assets" });
    expect(one.rows[0].nytt_felt).toBe("x");
    expect(one.problems[0]).toMatchObject({ column: "items.value", actual: "nope", row: 1 });

    let q = queue([{ status: 200, body: fx.slice(0, 3) }]);
    let r = await callTool(m, q.http, tool("brreg_regnskap"), { org_nr: "923609016", year: 2025, account_type: "SELSKAP" });
    expect(r.isError).toBe(false);
    expect(q.urls[0]).toMatch(/^https:\/\/data\.brreg\.no\/regnskapsregisteret\/regnskap\/923609016\?/);
    expect(q.urls[0]).toContain("%C3%A5r=2025");
    expect(q.urls[0]).toContain("regnskapstype=SELSKAP");
    expect(r.structuredContent.n_total).toBe(3);
    expect((r.structuredContent.columns as any[]).find((c) => c.name === "period_end").type).toBe("Date");
    expect((r.structuredContent.columns as any[]).find((c) => c.name === "items").type).toBe("list");
    expect(Array.isArray((r.structuredContent.rows as any[])[0].items)).toBe(true);

    q = queue([{ status: 500, body: { status: 500, message: "Regnskapet inneholder en oppstillingsplan som ikke er stottet (BANK)" } }]);
    r = await callTool(m, q.http, tool("brreg_regnskap"), { org_nr: "984851006" });
    expect(r.isError).toBe(false);
    expect((r.structuredContent.attributes as any)).toEqual({ http_status: 500, unsupported_plan: "BANK" });
    expect((r.structuredContent.conditions as any[])[0].class).toBe("tidybrreg_warning_unsupported_plan");
    expect((r.structuredContent.columns as any[]).map((c) => c.name)).toEqual(spec.result!.empty);

    q = queue([{ status: 500, body: { error: "boom" } }]);
    r = await callTool(m, q.http, tool("brreg_regnskap"), { org_nr: "923609016" });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_http");
    expect((r.structuredContent.error as any).fields.messages).toEqual(["boom"]);

    q = queue([{ status: 404 }]);
    r = await callTool(m, q.http, tool("brreg_regnskap"), { org_nr: "923609016" });
    expect((r.structuredContent.attributes as any).http_status).toBe(404);
  });

  it("feeds paginate on the exclusive cursor and keep raw pointers", async () => {
    const ev = (id: number, endringer?: unknown[]) => ({ oppdateringsid: id, organisasjonsnummer: "923609016", endringstype: "Endring", dato: "2026-03-15T10:30:00.000Z", endringer, nyttFelt: "x" });
    let q = queue([
      { status: 200, body: { _embedded: { oppdaterteEnheter: [ev(1), ev(2)] } } },
      { status: 200, body: { _embedded: { oppdaterteEnheter: [ev(3)] } } },
    ]);
    let r = await callTool(m, q.http, tool("brreg_updates"), { since: "2026-03-01", size: 2, max_pages: 5 });
    expect((r.structuredContent.rows as any[]).map((x) => x.update_id)).toEqual([1, 2, 3]);
    expect(q.urls[0]).toContain("dato=2026-03-01T00%3A00%3A00.000Z");
    expect(q.urls[1]).toContain("oppdateringsid=3");
    expect((r.structuredContent.attributes as any).complete).toBe(true);
    expect((r.structuredContent.attributes as any).unknown_members).toEqual(["nyttFelt"]);
    expect((r.structuredContent.rows as any[])[0].nytt_felt).toBe("x");
    expect((r.structuredContent.rows as any[])[0].timestamp).toBe("2026-03-15T10:30:00.000Z");

    q = queue([{ status: 200, body: { _embedded: { oppdaterteEnheter: [ev(1, [{ op: "add", path: "/x", value: { a: { b: "c" } } }]), ev(2)] } } }]);
    r = await callTool(m, q.http, tool("brreg_update_fields"), {});
    const rows = r.structuredContent.rows as any[];
    expect(rows).toHaveLength(2);
    expect(rows[0].path).toBe("/x/a/b");
    expect(rows[1].operation).toBeNull();
    expect(q.urls[0]).toContain("includeChanges=true");

    r = await callTool(m, q.http, tool("brreg_updates"), { type: "roller", include_changes: true });
    expect((r.structuredContent.error as any).class).toBe("tidybrreg_error_invalid_filter");
  });

  it("labels, dictionaries and validation run offline from the manifest", async () => {
    const q = queue([]);
    let r = await callTool(m, q.http, tool("brreg_label"), { x: ["AS", "ENK"], dic: "legal_form", lang: "no" });
    expect(r.structuredContent.value).toEqual(["Aksjeselskap", "Enkeltpersonforetak"]);
    r = await callTool(m, q.http, tool("brreg_label"), { x: [{ legal_form: "AS", nace_1: "06.100", employees: 1 }], code: ["legal_form"] });
    const row = (r.structuredContent.rows as any[])[0];
    expect(row.legal_form_code).toBe("AS");
    expect(row.legal_form).toBe("Private limited company");
    expect(row.nace_1).toMatch(/petroleum/i);
    r = await callTool(m, q.http, tool("get_brreg_dic"), { dictname: "nace", ".limit": 3 });
    expect(r.structuredContent.n_rows).toBe(3);
    expect(r.structuredContent.n_total).toBeGreaterThan(1000);
    expect((r.structuredContent.attributes as any).source).toBe("bundled");
    expect((r.structuredContent.attributes as any).vintage).toBe("2026-06-16");
    r = await callTool(m, q.http, tool("brreg_validate"), { org_nr: ["923609016", "123"] });
    expect(r.structuredContent.value).toEqual([true, false]);
    r = await callTool(m, q.http, tool("get_brreg_dic"), { dictname: "sector", ".format": "markdown", ".limit": 2 });
    expect(r.content[0].text).toMatch(/^2 of 33 rows/);
    r = await callTool(m, q.http, tool("brreg_entity"), { foo: 1 });
    expect(r.isError).toBe(true);
  });
});
