import { type ToolContext, type ToolResult, fnSpec, abortHttp, url, nz } from "./common.js";
import { TidybrregError } from "../conditions.js";
import { formatSince, parseBrregInstant } from "../dates.js";
import { toSnake, type Row } from "../parse.js";

const KNOWN_MEMBERS = ["oppdateringsid", "organisasjonsnummer", "endringstype", "dato", "endringer", "_links"];
const KNOWN_EVENT = ["specversion", "id", "source", "type", "time", "data", "datacontenttype", "subject"];
export const UPDATE_COLUMNS = ["update_id", "org_nr", "change_type", "timestamp"];
export const FIELD_COLUMNS = [...UPDATE_COLUMNS, "operation", "field", "path", "new_value"];

export interface Patch { operation: string | null; field: string | null; path: string | null; new_value: string | null }

function memberText(v: unknown): string | null {
  if (v === null || v === undefined) return null;
  if (typeof v === "object" && !Array.isArray(v)) return JSON.stringify(v);
  if (Array.isArray(v)) {
    if (v.length === 0) return null;
    if (v.some((e) => e !== null && typeof e === "object")) return JSON.stringify(v);
    return v.map((e) => String(e)).join("\n");
  }
  return String(v);
}

export function parsePatch(endringer: any[] | undefined | null): Patch[] {
  const out: Patch[] = [];
  const push = (op: string | null, path: string, value: string | null) =>
    out.push({ operation: op, field: path.replace(/^\//, "").replace(/\//g, "_"), path, new_value: value });
  const walk = (op: string | null, prefix: string, value: unknown) => {
    if (value === null || value === undefined || (Array.isArray(value) && value.length === 0)) { push(op, prefix, null); return; }
    if (Array.isArray(value)) { value.forEach((v, i) => walk(op, `${prefix}/${i}`, v)); return; }
    if (typeof value === "object") { for (const [k, v] of Object.entries(value as object)) walk(op, `${prefix}/${k}`, v); return; }
    push(op, prefix, String(value));
  };
  for (const e of endringer ?? []) {
    const op = e?.op ?? null;
    const path = e?.path ?? "";
    if (op === "remove" || e?.value === undefined || e?.value === null) { push(op, path, null); continue; }
    walk(op, path, e.value);
    if (op === "move" && e?.from) push("remove", e.from, null);
  }
  return out;
}

function parseUpdatesPage(raw: any[], includeChanges: boolean): { rows: Row[]; unknown: string[] } {
  const extra = new Set<string>();
  const rows: Row[] = raw.map((u) => {
    const row: Row = {
      update_id: u?.oppdateringsid != null ? Number(u.oppdateringsid) : null,
      org_nr: nz(u?.organisasjonsnummer),
      change_type: nz(u?.endringstype),
      timestamp: parseBrregInstant(u?.dato),
    };
    for (const k of Object.keys(u ?? {})) {
      if (KNOWN_MEMBERS.includes(k)) continue;
      extra.add(k);
      row[toSnake(k)] = memberText(u[k]);
    }
    if (includeChanges) row.changes = parsePatch(u?.endringer) as unknown as Record<string, unknown>[];
    return row;
  });
  return { rows, unknown: [...extra] };
}

interface FeedResult { pages: any[][]; complete: boolean; cursor: number | null; pagesFetched: number }

async function fetchHalPages(ctx: ToolContext, type: string, since: unknown, size: number, maxPages: number, includeChanges: boolean): Promise<FeedResult> {
  const spec = fnSpec(ctx.m, "brreg_updates");
  const route = spec.routes!.find((r) => r.type === type)!;
  const endpoint = route.path;
  const pages: any[][] = [];
  let cursor: number | null = null;
  let complete = true;
  let lastFull = false;
  for (let page = 1; page <= maxPages; page += 1) {
    const query: Record<string, string | number> = { size };
    if (cursor === null) query.dato = formatSince(since); else query.oppdateringsid = cursor + 1;
    if (includeChanges) query[spec.include_changes!.param] = spec.include_changes!.value;
    const resp = await ctx.http.get(url(ctx, spec, route, {}, query));
    if (resp.status >= 400) {
      if (pages.length === 0) await abortHttp(resp, endpoint);
      ctx.cond.warn("partial", `The ${type} feed failed with HTTP ${resp.status} after ${pages.length} page${pages.length === 1 ? "" : "s"}; returning the events read so far.`,
        { endpoint, status: resp.status, pages_fetched: pages.length });
      complete = false; lastFull = false; break;
    }
    const body = await resp.json();
    const raw: any[] = body?._embedded?.[route.embedded_key!] ?? [];
    if (raw.length === 0) { lastFull = false; break; }
    pages.push(raw);
    cursor = Math.max(...raw.map((u) => Number(u?.oppdateringsid ?? Number.NEGATIVE_INFINITY)));
    lastFull = raw.length >= size;
    if (!lastFull) break;
  }
  if (lastFull && pages.length === maxPages) {
    complete = false;
    ctx.cond.warn("truncated", `Stopped after ${maxPages} page${maxPages === 1 ? "" : "s"} with a full last page; more events may follow.\nRaise max_pages or resume from cursor + 1.`,
      { endpoint, returned: pages.length * size, total_matches: null });
  }
  return { pages, complete, cursor, pagesFetched: pages.length };
}

function finish(res: ToolResult, feed: FeedResult, unknown: string[], ctx: ToolContext, type: string): ToolResult {
  res.attributes.complete = feed.complete;
  res.attributes.pages_fetched = feed.pagesFetched;
  res.attributes.cursor = feed.cursor;
  if (unknown.length > 0) {
    res.attributes.unknown_members = unknown;
    ctx.cond.warn("unknown_member", `The ${type} feed carried members not modelled by tidybrreg: ${unknown.join(", ")}.\nThey are passed through as columns.`, { members: unknown });
  }
  return res;
}

export async function brreg_updates(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const type = String(args.type ?? "enheter");
  const size = Math.min(Math.trunc(Number(args.size ?? 100)), 10000);
  const maxPages = Math.trunc(Number(args.max_pages ?? 1));
  const includeChanges = args.include_changes === true;
  if (type === "roller") {
    if (includeChanges) {
      throw new TidybrregError("invalid_filter", "`include_changes` is not available for \"roller\".\nThe roller feed carries no field patches; fetch the new state with brreg_roles.", { registry: "roller", filter: "include_changes" });
    }
    return rollerUpdates(ctx, args.since, size, maxPages);
  }
  const feed = await fetchHalPages(ctx, type, args.since, size, maxPages, includeChanges);
  const rows: Row[] = [];
  const unknown = new Set<string>();
  for (const p of feed.pages) {
    const parsed = parseUpdatesPage(p, includeChanges);
    rows.push(...parsed.rows);
    parsed.unknown.forEach((u) => unknown.add(u));
  }
  const cols = includeChanges ? [...UPDATE_COLUMNS, "changes"] : UPDATE_COLUMNS;
  return finish({ kind: "table", rows, columns: cols, attributes: {} }, feed, [...unknown], ctx, type);
}

export async function brreg_update_fields(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const type = String(args.type ?? "enheter");
  if (!["enheter", "underenheter"].includes(type)) {
    throw new TidybrregError("invalid_filter", `\`type\` must be one of "enheter", "underenheter", not "${type}".`, { registry: type, filter: "type" });
  }
  const size = Math.min(Math.trunc(Number(args.size ?? 100)), 10000);
  const maxPages = Math.trunc(Number(args.max_pages ?? 1));
  const feed = await fetchHalPages(ctx, type, args.since, size, maxPages, true);
  const rows: Row[] = [];
  const unknown = new Set<string>();
  for (const p of feed.pages) {
    const parsed = parseUpdatesPage(p, true);
    parsed.unknown.forEach((u) => unknown.add(u));
    for (const r of parsed.rows) {
      const { changes, ...meta } = r;
      const patches = (changes as unknown as Patch[]) ?? [];
      if (patches.length === 0) rows.push({ ...meta, operation: null, field: null, path: null, new_value: null });
      else for (const p2 of patches) rows.push({ ...meta, ...p2 });
    }
  }
  return finish({ kind: "table", rows, columns: FIELD_COLUMNS, attributes: {} }, feed, [...unknown], ctx, type);
}

async function rollerUpdates(ctx: ToolContext, since: unknown, size: number, maxPages: number): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, "brreg_updates");
  const route = spec.routes!.find((r) => r.type === "roller")!;
  const endpoint = route.path;
  const rows: Row[] = [];
  const unknown = new Set<string>();
  let cursor: number | null = null;
  let complete = true;
  let lastFull = false;
  let pagesFetched = 0;
  for (let page = 1; page <= maxPages; page += 1) {
    const query: Record<string, string | number> = { size };
    if (cursor === null) query.afterTime = formatSince(since); else query.afterId = cursor;
    const resp = await ctx.http.get(url(ctx, spec, route, {}, query));
    if (resp.status >= 400) {
      if (pagesFetched === 0) await abortHttp(resp, endpoint);
      ctx.cond.warn("partial", `The roller feed failed with HTTP ${resp.status} after ${pagesFetched} page${pagesFetched === 1 ? "" : "s"}; returning the events read so far.`,
        { endpoint, status: resp.status, pages_fetched: pagesFetched });
      complete = false; lastFull = false; break;
    }
    const events: any[] = await resp.json();
    if (!Array.isArray(events) || events.length === 0) { lastFull = false; break; }
    pagesFetched += 1;
    for (const e of events) {
      const row: Row = {
        update_id: e?.id != null ? Number(e.id) : null,
        org_nr: nz(e?.data?.organisasjonsnummer),
        change_type: String(e?.type ?? "").replace(/.*\./, ""),
        timestamp: parseBrregInstant(e?.time),
      };
      for (const k of Object.keys(e ?? {})) {
        if (KNOWN_EVENT.includes(k)) continue;
        unknown.add(k);
        row[toSnake(k)] = memberText(e[k]);
      }
      rows.push(row);
    }
    cursor = Math.max(...events.map((e) => Number(e?.id ?? Number.NEGATIVE_INFINITY)));
    lastFull = events.length >= size;
    if (!lastFull) break;
  }
  if (lastFull && pagesFetched === maxPages) {
    complete = false;
    ctx.cond.warn("truncated", `Stopped after ${maxPages} page${maxPages === 1 ? "" : "s"} with a full last page; more events may follow.\nRaise max_pages or resume from cursor.`,
      { endpoint, returned: pagesFetched * size, total_matches: null });
  }
  return finish({ kind: "table", rows, columns: UPDATE_COLUMNS, attributes: {} },
    { pages: [], complete, cursor, pagesFetched }, [...unknown], ctx, "roller");
}
