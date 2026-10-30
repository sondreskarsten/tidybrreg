import { type ToolContext, type ToolResult, fnSpec, checkOrgNr, satelliteStatus, lookupRole, lookupRoleGroup, personId, url, nz } from "./common.js";
import { parseBrregDate } from "../dates.js";
import { flattenJson, renameThrough, coerceRows, isHalLinkPath, toSnake, type Row, type FieldMap } from "../parse.js";
import type { FunctionSpec } from "../manifest.js";
import type { BrregResponse } from "../http.js";
import { labelRows } from "./label.js";

function emptyColumns(spec: ReturnType<typeof fnSpec>): string[] {
  return (spec.result?.empty as string[]) ?? [];
}

async function satellite(ctx: ToolContext, name: string, args: Record<string, unknown>,
                         flatten: (raw: any, org_nr: string) => Row[]): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, name);
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  const route = spec.routes![0];
  const endpoint = route.path.replace("{org_nr}", org_nr);
  const resp = await ctx.http.get(url(ctx, spec, route, { org_nr }));
  const cols = emptyColumns(spec);
  const early = await satelliteStatus(ctx, resp, endpoint, org_nr, cols);
  if (early) return early;
  const rows = flatten(await resp.json(), org_nr);
  return { kind: "table", rows, columns: cols, attributes: {} };
}

function entityName(navn: unknown): string | null {
  if (navn === null || navn === undefined) return null;
  if (typeof navn === "string") return navn;
  if (Array.isArray(navn)) return navn.map(String).join(" ");
  if (typeof navn === "object") return ((navn as any).navnelinje1 as string) ?? null;
  return String(navn);
}

export function flattenRoles(ctx: ToolContext, raw: any, org_nr: string): Row[] {
  const rows: Row[] = [];
  let anyFratraadt = false;
  for (const g of raw?.rollegrupper ?? []) {
    if (!g?.roller) continue;
    const g_code = g?.type?.kode ?? null;
    const g_modified = parseBrregDate(g?.sistEndret);
    for (const r of g.roller) {
      if (r?.fratraadt !== undefined && r?.fratraadt !== null) anyFratraadt = true;
      const row: Row = {
        org_nr,
        role_group_code: g_code,
        role_group: lookupRoleGroup(ctx.m, g_code),
        role_code: r?.type?.kode ?? null,
        role: lookupRole(ctx.m, r?.type?.kode),
        first_name: nz(r?.person?.navn?.fornavn),
        middle_name: nz(r?.person?.navn?.mellomnavn),
        last_name: nz(r?.person?.navn?.etternavn),
        birth_date: parseBrregDate(r?.person?.fodselsdato),
        deceased: nz(r?.person?.erDoed),
        entity_org_nr: nz(r?.enhet?.organisasjonsnummer),
        entity_name: entityName(r?.enhet?.navn),
        resigned: nz(r?.fratraadt),
        deregistered: nz(r?.avregistrert),
        ordering: nz(r?.rekkefolge),
        elected_by: nz(r?.valgtAv?.kode),
        group_modified: g_modified,
      };
      row.person_id = personId(row);
      rows.push(row);
    }
  }
  for (const r of rows) {
    if (anyFratraadt) { if (r.resigned == null) r.resigned = false; } else delete r.resigned;
  }
  return rows;
}

export async function brreg_roles(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  return satellite(ctx, "brreg_roles", args, (raw, org) => flattenRoles(ctx, raw, org));
}

export function flattenRolesLegal(ctx: ToolContext, raw: any, org_nr: string): Row[] {
  const rows: Row[] = [];
  let anyFratraadt = false;
  for (const e of raw?.enheter ?? []) {
    for (const r of e?.roller ?? []) {
      if (r?.fratraadt !== undefined && r?.fratraadt !== null) anyFratraadt = true;
      rows.push({
        org_nr,
        target_org_nr: nz(e?.organisasjonsnummer),
        target_name: nz(e?.navn),
        role_code: nz(r?.type?.kode),
        role: lookupRole(ctx.m, r?.type?.kode),
        share: nz(r?.ansvarsandel),
        resigned: nz(r?.fratraadt),
        deregistered: r?.avregistrert ?? false,
      });
    }
  }
  for (const r of rows) {
    if (anyFratraadt) { if (r.resigned == null) r.resigned = false; } else delete r.resigned;
  }
  return rows;
}

export async function brreg_roles_legal(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  return satellite(ctx, "brreg_roles_legal", args, (raw, org) => flattenRolesLegal(ctx, raw, org));
}

export function flattenKonsern(raw: any, org_nr: string): Row[] {
  const rows: Row[] = [];
  const emit = (node: any, depth: number, parent_org: string | null, parent_name: string | null) => {
    const isRoot = depth === 0;
    rows.push({
      org_nr,
      node_org_nr: nz(node?.organisasjonsnummer),
      node_name: nz(node?.navn),
      level: node?.nivaa != null ? Number(node.nivaa) : depth,
      link_form: node?.knytningsform?.kode ?? (isRoot ? "KKKK" : null),
      link_form_desc: node?.knytningsform?.beskrivelse ?? (isRoot ? "Øverste mor" : null),
      basis: nz(node?.grunnlag),
      relation_date: parseBrregDate(node?.dato),
      parent_org_nr: node?.parentOrganisasjonsnummer ?? parent_org,
      parent_name: node?.parentNavn ?? parent_name,
      legal_form: nz(node?.organisasjonsform?.kode),
      legal_form_desc: nz(node?.organisasjonsform?.beskrivelse),
    });
    for (const ch of node?.children ?? []) emit(ch, depth + 1, node?.organisasjonsnummer ?? null, node?.navn ?? null);
  };
  emit(raw, 0, null, null);
  return rows;
}

export async function brreg_konsern(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  return satellite(ctx, "brreg_konsern", args, flattenKonsern);
}

/** HTTP 200 without combinations but with status.rutineStatus: a rule the service declines to resolve. */
export function unresolvedSignatur(ctx: ToolContext, raw: any, org_nr: string, signature_type: string, cols: string[]): ToolResult | null {
  const komb = raw?.signeringsKombinasjon?.kombinasjon ?? [];
  const routine = raw?.status?.rutineStatus;
  if (komb.length > 0 || !routine) return null;
  const routine_status = routine?.kode ?? null;
  const routine_text = routine?.tekstforklaring ?? null;
  ctx.cond.warn("unresolved", `The Fullmakt service declined to resolve the ${signature_type} rule of entity "${org_nr}" (routine status ${JSON.stringify(routine_status)}).${routine_text ? `\n${routine_text}` : ""}`,
    { org_nr, signature_type, routine_status, routine_text });
  return { kind: "table", rows: [], columns: cols, attributes: { http_status: 200, routine_status, routine_text } };
}

export function flattenSignatur(ctx: ToolContext, raw: any, org_nr: string, signature_type: string): Row[] {
  const komb = raw?.signeringsKombinasjon?.kombinasjon ?? [];
  const entity_name = raw?.enhet?.navn ?? null;
  const rule_status = raw?.status?.regelStatus?.kode ?? null;
  const rule_text = raw?.signeringsGrunnlag?.signaturProkuraRoller?.signaturProkuraFritekst ?? null;
  const rows: Row[] = [];
  for (const kb of komb) {
    const base = {
      org_nr, entity_name, signature_type, rule_status, rule_text,
      combination_id: kb?.kombinasjonsId != null ? String(kb.kombinasjonsId) : null,
      combination_code: nz(kb?.kode),
      rule: nz(kb?.tekstforklaring),
    };
    const persons = kb?.personRolleKombinasjon ?? [];
    if (persons.length === 0) {
      rows.push({ ...base, name: null, birth_date: null, role_code: null, role: null });
      continue;
    }
    for (const p of persons) {
      rows.push({ ...base, name: nz(p?.navn), birth_date: parseBrregDate(p?.fodselsdato), role_code: nz(p?.rolle?.kode), role: lookupRole(ctx.m, p?.rolle?.kode) });
    }
  }
  return rows;
}

async function fullmakt(ctx: ToolContext, name: string, args: Record<string, unknown>, fallback: string): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, name);
  const t = spec.fixed_columns?.signature_type ?? fallback;
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  const route = spec.routes![0];
  const endpoint = route.path.replace("{org_nr}", org_nr);
  const resp = await ctx.http.get(url(ctx, spec, route, { org_nr }));
  const cols = emptyColumns(spec);
  const early = await satelliteStatus(ctx, resp, endpoint, org_nr, cols);
  if (early) return early;
  const raw = await resp.json();
  const unresolved = unresolvedSignatur(ctx, raw, org_nr, t, cols);
  if (unresolved) return unresolved;
  return { kind: "table", rows: flattenSignatur(ctx, raw, org_nr, t), columns: cols, attributes: {} };
}

export async function brreg_signatur(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  return fullmakt(ctx, "brreg_signatur", args, "signature");
}

export async function brreg_prokura(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  return fullmakt(ctx, "brreg_prokura", args, "procuration");
}

export interface RegnskapItem { statement: string; group: string; item: string; path: string; level: number; is_sum: boolean; value: number | null }

function statementOf(spec: FunctionSpec, path: string): string | null {
  return spec.statements?.[path.split(".")[0]] ?? null;
}

/** The filing's line items: one per leaf inside a statement object, keeping the API's structure. */
export function buildItems(spec: FunctionSpec, flat: Record<string, unknown>): { items: RegnskapItem[]; failed: { index: number; actual: string }[] } {
  const fields = (spec.fields ?? []) as FieldMap;
  const groups = spec.groups ?? [];
  const items: RegnskapItem[] = [];
  const failed: { index: number; actual: string }[] = [];
  let index = 0;
  for (const [path, v] of Object.entries(flat)) {
    index += 1;
    const statement = statementOf(spec, path)!;
    const parts = path.split(".");
    const leaf = parts[parts.length - 1];
    const node = parts.slice(0, -1).join(".");
    let group = groups.find((g) => g.path === node)?.code;
    if (group === undefined) group = parts.length < 2 ? statement : toSnake(parts[parts.length - 2]);
    const item = fields.find((f) => f.api_path === path)?.col_name ?? toSnake(leaf);
    const present = !(v === null || v === undefined || (typeof v === "string" && v.trim() === ""));
    let value: number | null = null;
    if (typeof v === "number") value = v;
    else if (present) {
      const n = Number(String(v).trim());
      value = Number.isFinite(n) ? n : null;
      if (value === null) failed.push({ index, actual: String(v) });
    }
    items.push({ statement, group, item, path, level: parts.length - 1, is_sum: leaf.startsWith("sum"), value });
  }
  return { items, failed };
}

/** The accounting identities of one filing, by item name, within the spec's tolerance. */
export function checkIdentities(spec: FunctionSpec, items: RegnskapItem[]): { consistent: boolean | null; inconsistencies: string[] } {
  const valueOf = (name: string): number | null => items.find((i) => i.item === name)?.value ?? null;
  const checked: string[] = []; const failed: string[] = [];
  for (const rule of spec.identities?.rules ?? []) {
    const lhs = valueOf(rule.lhs);
    const terms = [...rule.plus, ...rule.minus];
    const vals = new Map(terms.map((t) => [t, valueOf(t)]));
    if (lhs === null || terms.some((t) => !rule.optional.includes(t) && vals.get(t) === null)) continue;
    const rhs = rule.plus.reduce((a, t) => a + (vals.get(t) ?? 0), 0) - rule.minus.reduce((a, t) => a + (vals.get(t) ?? 0), 0);
    checked.push(rule.name);
    if (Math.abs(lhs - rhs) > (spec.identities?.tolerance ?? 0)) failed.push(rule.name);
  }
  return { consistent: checked.length === 0 ? null : failed.length === 0, inconsistencies: failed };
}

/** One nested row per filing: scalars renamed through the field map, items built from the statement leaves, identities checked. */
export function flattenRegnskap(spec: FunctionSpec, raw: any, org_nr: string): { rows: Row[]; types: Map<string, string>; problems: ReturnType<typeof coerceRows> } {
  const fields = (spec.fields ?? []) as FieldMap;
  const rows: Row[] = [];
  const types = new Map<string, string>();
  const problems: ReturnType<typeof coerceRows> = [];
  const filings = Array.isArray(raw) ? raw : [];
  filings.forEach((filing, i) => {
    const flat = flattenJson(filing ?? {});
    const inStatement: Record<string, unknown> = {}; const outside: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(flat)) {
      if (isHalLinkPath(k)) continue;
      if (statementOf(spec, k) !== null) inStatement[k] = v; else outside[k] = v;
    }
    const built = buildItems(spec, inStatement);
    const r = renameThrough(fields, outside);
    if (!("org_nr" in r.row)) r.row.org_nr = org_nr;
    const rowProblems = coerceRows([r.row], r.types);
    for (const p of rowProblems) problems.push({ ...p, row: i + 1 });
    for (const f of built.failed) problems.push({ column: "items.value", row: i + 1, expected: "numeric", actual: f.actual, n_failed: 1 });
    for (const [k, v] of r.types) if (!types.has(k)) types.set(k, v);
    const flags = checkIdentities(spec, built.items);
    rows.push({ org_nr: r.row.org_nr, ...r.row, items: built.items as unknown as Record<string, unknown>[], consistent: flags.consistent, inconsistencies: flags.inconsistencies });
  });
  types.set("items", "list"); types.set("consistent", "logical"); types.set("inconsistencies", "list");
  const byColumn = new Map<string, number>();
  for (const p of problems) byColumn.set(p.column, (byColumn.get(p.column) ?? 0) + 1);
  for (const p of problems) p.n_failed = byColumn.get(p.column)!;
  return { rows, types, problems };
}

const UNSUPPORTED_PLAN = "oppstillingsplan som ikke er st";

export async function brreg_regnskap(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, "brreg_regnskap");
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  const route = spec.routes![0];
  const endpoint = route.path.replace("{org_nr}", org_nr);
  const q = spec.query as Record<string, string>;
  const query: Record<string, string | number | null> = {};
  query[q.year] = args.year == null ? null : Number(args.year);
  query[q.account_type] = args.account_type == null ? null : String(args.account_type);
  const cols = (spec.result?.empty as string[]) ?? [];
  let resp = await ctx.http.get(url(ctx, spec, route, { org_nr }, query));
  if (resp.status === 500) {
    let body: any = null;
    try { body = await resp.json(); } catch { body = null; }
    const message = String(body?.message ?? "");
    if (message.includes(UNSUPPORTED_PLAN)) {
      const plan = /\(([A-Z]+)\)/.exec(message)?.[1] ?? null;
      ctx.cond.warn("unsupported_plan", `Entity "${org_nr}" files accounts under a plan the API does not serve (${plan ?? "NA"}).`, { org_nr, plan, api_message: message });
      return { kind: "table", rows: [], columns: cols, attributes: { http_status: 500, unsupported_plan: plan } };
    }
    const replay: BrregResponse = { ...resp, json: async () => body, text: async () => JSON.stringify(body) };
    resp = replay;
  }
  const early = await satelliteStatus(ctx, resp, endpoint, org_nr, cols);
  if (early) return early;
  let { rows, types, problems } = flattenRegnskap(spec, await resp.json(), org_nr);
  if (String(args.type ?? "code") === "label") rows = await labelRows(ctx, rows, "en");
  if (problems.length > 0) {
    const columns = new Set(problems.map((p) => p.column));
    const n = [...columns].reduce((acc, c) => acc + problems.find((p) => p.column === c)!.n_failed, 0);
    ctx.cond.warn("parse", `${n} parse failure(s) in ${columns.size} column(s).`, { n });
  }
  const attributes: Record<string, unknown> = {};
  if (problems.length > 0) attributes.brreg_parse_problems = problems;
  return { kind: "table", rows, columns: cols, columnTypes: types, attributes };
}
