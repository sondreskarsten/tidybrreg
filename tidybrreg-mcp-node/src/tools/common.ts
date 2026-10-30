import type { Manifest, FunctionSpec, Route } from "../manifest.js";
import { Http, buildUrl, errorMessages, type BrregResponse } from "../http.js";
import { Conditions, TidybrregError } from "../conditions.js";
import { parseBrregDate } from "../dates.js";
import type { Row } from "../parse.js";

export interface ToolContext {
  m: Manifest;
  http: Http;
  cond: Conditions;
}

/** A tool's result before shaping: a table (rows + typed empty columns) or a value. */
export interface ToolResult {
  kind: "table" | "vector" | "scalar" | "value";
  rows?: Row[];
  columns?: string[];
  columnTypes?: Map<string, string>;
  value?: unknown;
  attributes: Record<string, unknown>;
}

export function fnSpec(m: Manifest, name: string): FunctionSpec {
  const s = m.endpoints.functions[name];
  if (!s) throw new TidybrregError("internal", `No endpoint specification for ${name}`);
  return s;
}

export function serviceBase(m: Manifest, service: string | null | undefined): string {
  const base = service ? m.endpoints.services[service] : undefined;
  if (!base) throw new TidybrregError("internal", `Unknown service ${service}`);
  return base;
}

export function routePath(route: Route, params: Record<string, string>): string {
  return route.path.replace(/\{(\w+)\}/g, (_, k) => {
    const v = params[k];
    if (v === undefined) throw new TidybrregError("internal", `Missing path parameter ${k}`);
    return encodeURIComponent(v);
  });
}

export function checkOrgNr(m: Manifest, org_nr: unknown, arg = "org_nr"): string {
  if (Array.isArray(org_nr)) {
    if (org_nr.length !== 1) {
      throw new TidybrregError("invalid_org_nr", `\`${arg}\` must be a single organization number, not ${org_nr.length}.`, { org_nr });
    }
    org_nr = org_nr[0];
  }
  const s = org_nr === null || org_nr === undefined ? "" : String(org_nr);
  if (!validateOrgNr(m, s)) {
    throw new TidybrregError("invalid_org_nr",
      `Invalid organization number: "${s}"\nMust be 9 digits starting with 8 or 9, with a modulus-11 check digit.\nExamples: 923609016 (Equinor), 984851006 (DNB Bank)`,
      { org_nr: s });
  }
  return s;
}

export function validateOrgNr(m: Manifest, x: string): boolean {
  if (!new RegExp(m.endpoints.org_nr.pattern).test(x)) return false;
  const d = x.split("").map(Number);
  const w = [3, 2, 7, 6, 5, 4, 3, 2];
  const r = d.slice(0, 8).reduce((acc, v, i) => acc + v * w[i], 0) % 11;
  const check = r === 0 ? 0 : 11 - r;
  return check < 10 && check === d[8];
}

export async function abortHttp(resp: BrregResponse, endpoint: string): Promise<never> {
  const messages = await errorMessages(resp);
  throw new TidybrregError("http",
    [`Norwegian Business Registry API error: HTTP ${resp.status} for ${endpoint}.`, ...messages].join("\n"),
    { endpoint, status: resp.status, messages });
}

/** Status contract shared by the satellite endpoints (see ?brreg_roles). */
export async function satelliteStatus(ctx: ToolContext, resp: BrregResponse, endpoint: string, org_nr: string,
                                      emptyColumns: string[]): Promise<ToolResult | null> {
  if (resp.status === 200) return null;
  if (resp.status === 404) {
    return { kind: "table", rows: [], columns: emptyColumns, attributes: { http_status: 404 } };
  }
  if (resp.status === 410) {
    let body: any = {};
    try { body = await resp.json(); } catch { /* no body */ }
    const deletion_date = parseBrregDate(body?.slettedato);
    ctx.cond.warn("deleted", `Entity "${org_nr}" was deleted on ${deletion_date ?? "NA"}.`, { org_nr, deletion_date });
    return { kind: "table", rows: [], columns: emptyColumns, attributes: { http_status: 410, deletion_date } };
  }
  return abortHttp(resp, endpoint);
}

export function lookupRole(m: Manifest, code: unknown): string | null {
  if (code === null || code === undefined) return null;
  const hit = m.dictionaries.role_types.find((r) => r.code === String(code));
  return hit ? (hit.name_en as string) : String(code);
}

export function lookupRoleGroup(m: Manifest, code: unknown): string | null {
  if (code === null || code === undefined) return null;
  const hit = m.dictionaries.role_groups.find((r) => r.code === String(code));
  return hit ? (hit.name_en as string) : String(code);
}

export function personId(r: Row): string | null {
  if (r.birth_date == null || r.last_name == null) return null;
  const mid = r.middle_name == null ? "" : String(r.middle_name).toLowerCase();
  return [String(r.birth_date), String(r.last_name).toLowerCase(), String(r.first_name ?? "").toLowerCase(), mid].join("_");
}

export function url(ctx: ToolContext, spec: FunctionSpec, route: Route, params: Record<string, string>, query: Record<string, string | number | boolean | null | undefined> = {}): string {
  return buildUrl(serviceBase(ctx.m, spec.service), routePath(route, params), query);
}

export function nz(v: unknown): Row[keyof Row] {
  return v === undefined ? null : (v as Row[keyof Row]);
}
