import { type ToolContext, type ToolResult, fnSpec, checkOrgNr, abortHttp, url } from "./common.js";
import { TidybrregError } from "../conditions.js";
import { parseBrregDate } from "../dates.js";
import { parseEntity, parseEntities, EMPTY_ENTITY_COLUMNS, type Row } from "../parse.js";
import { labelRows } from "./label.js";

function reportProblems(ctx: ToolContext, problems: { column: string; n_failed: number }[]): Row[] | void {
  if (problems.length === 0) return;
  const cols = new Set(problems.map((p) => p.column));
  const n = [...cols].reduce((acc, c) => acc + (problems.find((p) => p.column === c)?.n_failed ?? 0), 0);
  ctx.cond.warn("parse", `${n} parse failure${n === 1 ? "" : "s"} in ${cols.size} column${cols.size === 1 ? "" : "s"}.`, { n });
}

export async function brreg_entity(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, "brreg_entity");
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  const registry = String(args.registry ?? "auto");
  const type = String(args.type ?? "code");
  const order = registry === "auto" ? (spec.auto_order as string[]) : [registry];
  const routes = spec.routes ?? [];

  let resp = null as Awaited<ReturnType<typeof ctx.http.get>> | null;
  let matched: string | null = null;
  let endpoint = "";
  for (const reg of order) {
    const route = routes.find((r) => r.registry === reg);
    if (!route) throw new TidybrregError("internal", `No route for registry ${reg}`);
    endpoint = route.path.replace("{org_nr}", org_nr);
    resp = await ctx.http.get(url(ctx, spec, route, { org_nr }));
    if (resp.status === 200 || resp.status === 410) { matched = reg; break; }
    if (resp.status !== 404) break;
  }
  if (!resp) throw new TidybrregError("internal", "no response");
  if (resp.status === 404) {
    throw new TidybrregError("not_found", `Entity "${org_nr}" not found in the Norwegian Business Registry.\nSearched: ${order.join(", ")}`,
      { org_nr, endpoint, status: 404 });
  }
  if (resp.status !== 200 && resp.status !== 410) await abortHttp(resp, endpoint);

  const body = await resp.json();
  const parsed = parseEntity(ctx.m, body);
  const row = parsed.rows[0];
  if (!("org_nr" in row)) row.org_nr = org_nr;
  row.registry = matched;
  const deleted = resp.status === 410 || body?.respons_klasse === "SlettetEnhet" || body?.slettedato != null;
  row.deleted = deleted;
  if (deleted) {
    if (!("deletion_date" in row)) row.deletion_date = parseBrregDate(body?.slettedato);
    ctx.cond.warn("deleted", `Entity "${org_nr}" was deleted on ${row.deletion_date ?? "NA"}.`, { org_nr, deletion_date: row.deletion_date });
  }
  reportProblems(ctx, parsed.problems);
  let rows = parsed.rows;
  if (type === "label") rows = await labelRows(ctx, rows, "en");
  const attributes: Record<string, unknown> = {};
  if (parsed.problems.length > 0) attributes.brreg_parse_problems = { n_rows: parsed.problems.length };
  const types = new Map(parsed.types);
  types.set("registry", "character"); types.set("deleted", "logical");
  return { kind: "table", rows, columnTypes: types, attributes };
}

export async function brreg_search(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, "brreg_search");
  const registry = String(args.registry ?? "enheter");
  const type = String(args.type ?? "code");
  const max_results = Math.trunc(Number(args.max_results ?? 200));
  if (!Number.isFinite(max_results) || max_results < 1) {
    throw new TidybrregError("invalid_filter", "`max_results` must be a single positive integer.", { registry, filter: "max_results" });
  }
  const q = spec.query as Record<string, string | Record<string, string | null>>;
  const pg = spec.pagination as { page_param: string; size_param: string; page_size: number; retrieval_limit: number };
  const route = (spec.routes ?? []).find((r) => r.registry === registry);
  if (!route) throw new TidybrregError("invalid_filter", `Unknown registry ${registry}`, { registry, filter: "registry" });

  const filters: Record<string, unknown> = {};
  const query: Record<string, string | number | null | undefined> = {};
  for (const [arg, mapping] of Object.entries(q)) {
    const v = args[arg];
    if (v === undefined || v === null) continue;
    filters[arg] = v;
    const param = typeof mapping === "string" ? mapping : mapping[registry];
    if (param === null || param === undefined) {
      throw new TidybrregError("invalid_filter",
        `\`${arg}\` is not supported for "${registry}".\nThe sub-entity search endpoint has no \`konkurs\` filter; query the parent entity instead.`,
        { registry, filter: arg });
    }
    query[param] = typeof v === "boolean" ? String(v) : String(v);
  }
  const size = Math.min(pg.page_size, max_results);
  let page = 0;
  const items: Record<string, unknown>[] = [];
  let total: number | null = null;
  let pages = 0;
  let complete = true;

  for (;;) {
    const resp = await ctx.http.get(url(ctx, spec, route, {}, { ...query, [pg.size_param]: size, [pg.page_param]: page }));
    if (resp.status >= 400) {
      if (pages === 0) await abortHttp(resp, registry);
      ctx.cond.warn("partial", `Search failed with HTTP ${resp.status} after ${pages} page${pages === 1 ? "" : "s"}; returning the ${items.length} entities retrieved so far.`,
        { endpoint: registry, status: resp.status, pages_fetched: pages });
      complete = false;
      break;
    }
    const body = await resp.json();
    pages += 1;
    if (total === null) {
      total = typeof body?.page?.totalElements === "number" ? body.page.totalElements : null;
      if (total !== null && total > pg.retrieval_limit && max_results > pg.retrieval_limit) {
        throw new TidybrregError("result_window",
          `The query matches ${total.toLocaleString("en")} entities, more than the ${pg.retrieval_limit.toLocaleString("en")} the search endpoint can return.\nNarrow the query (e.g. by municipality_code, legal_form, nace_code) and combine the partitions, or set max_results at or below ${pg.retrieval_limit.toLocaleString("en")} to accept the first matches only.\nFor the full register use brreg_download.`,
          { endpoint: registry, total_matches: total, retrieval_limit: pg.retrieval_limit, filters });
      }
    }
    const got: Record<string, unknown>[] = body?._embedded?.[route.embedded_key ?? registry] ?? [];
    if (got.length === 0) break;
    items.push(...got);
    if (items.length >= max_results) break;
    if (!body?._links?.next) break;
    page += 1;
    if ((page + 1) * size > pg.retrieval_limit) break;
  }

  const n = Math.min(items.length, max_results);
  const parsed = parseEntities(ctx.m, items.slice(0, n));
  reportProblems(ctx, parsed.problems);
  let rows = parsed.rows;
  total = total ?? n;
  if (total > n) {
    complete = false;
    ctx.cond.warn("truncated", `Returned ${n} of ${total.toLocaleString("en")} matching entities.\nRaise max_results (up to 10,000) or narrow the query; the result carries complete = FALSE.`,
      { endpoint: registry, returned: n, total_matches: total });
  }
  if (type === "label" && n > 0) rows = await labelRows(ctx, rows, "en");
  return {
    kind: "table", rows, columns: EMPTY_ENTITY_COLUMNS, columnTypes: parsed.types,
    attributes: { total_matches: total, complete },
  };
}

export async function brreg_underenheter(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  return brreg_search(ctx, { parent_org_nr: org_nr, registry: "underenheter", max_results: args.max_results ?? 200, type: args.type ?? "code" });
}

export async function brreg_children(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const org_nr = checkOrgNr(ctx.m, args.org_nr);
  return brreg_search(ctx, { parent_org_nr: org_nr, registry: "enheter", max_results: args.max_results ?? 200, type: args.type ?? "code" });
}

export async function brreg_validate(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const input = args.org_nr;
  const values = (Array.isArray(input) ? input : [input]).map((v) => (v === null || v === undefined ? "NA" : String(v)));
  const { validateOrgNr } = await import("./common.js");
  const out = values.map((v) => validateOrgNr(ctx.m, v));
  return { kind: out.length === 1 ? "scalar" : "vector", value: out.length === 1 ? out[0] : out, attributes: {} };
}
