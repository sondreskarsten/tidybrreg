import { type ToolContext, type ToolResult, fnSpec, url } from "./common.js";
import { TidybrregError } from "../conditions.js";
import type { Row } from "../parse.js";
import type { Manifest } from "../manifest.js";

const COLUMN_DICS: Record<string, string> = {
  legal_form: "legal_form", nace_1: "nace", nace_2: "nace", nace_3: "nace",
  sector_code: "sector", role_code: "role", role_group_code: "role_group",
  item: "regnskap_item", group: "regnskap_group", statement: "regnskap_group",
};

export interface Dictionary { rows: { code: string; name: string; level: string | null }[]; source: "klass" | "bundled"; lang: string; vintage: string }

const cache = new Map<string, Dictionary>();

export function offline(): boolean {
  return ["1", "true", "TRUE"].includes(process.env.TIDYBRREG_OFFLINE ?? "");
}

export function bundledDic(m: Manifest, dictname: string, lang: string): Dictionary {
  if (lang !== "en") {
    throw new TidybrregError("no_bundled_dictionary",
      `No bundled "${lang}" dictionary for "${dictname}".\nNorwegian labels are available from SSB KLASS only; use source = "klass" with network access.`,
      { dictname, lang });
  }
  const d = dictname === "nace" ? m.dictionaries.nace_codes : m.dictionaries.sector_codes;
  return { rows: d.rows.map((r) => ({ code: String(r.code), name: String(r.name), level: r.level == null ? null : String(r.level) })), source: "bundled", lang: "en", vintage: d.vintage };
}

export async function klassDic(ctx: ToolContext, dictname: string, lang: string): Promise<Dictionary> {
  const spec = fnSpec(ctx.m, "get_brreg_dic");
  const route = spec.routes!.find((r) => r.dictname === dictname)!;
  const date = new Date().toISOString().slice(0, 10);
  const resp = await ctx.http.get(url(ctx, spec, route, {}, { date, language: lang === "no" ? "nb" : lang }), "application/json");
  if (resp.status >= 400) throw new TidybrregError("http", `SSB KLASS API error: HTTP ${resp.status} for ${route.path}.`, { endpoint: route.path, status: resp.status, messages: [] });
  const body = await resp.json();
  const rows = (body?.codes ?? []).map((c: any) => ({ code: String(c.code), name: String(c.name), level: c.level == null ? null : String(c.level) }));
  return { rows, source: "klass", lang, vintage: date };
}

export async function getDictionary(ctx: ToolContext, dictname: string, lang = "en", source = "auto", refresh = false): Promise<Dictionary> {
  if (!["nace", "sector"].includes(dictname)) throw new TidybrregError("invalid_filter", `dictname must be "nace" or "sector", not "${dictname}".`, { filter: "dictname" });
  if (!["en", "no"].includes(lang)) throw new TidybrregError("invalid_filter", `lang must be "en" or "no".`, { filter: "lang" });
  if (source === "auto" && offline()) source = "bundled";
  const key = `${dictname}_${lang}_${source}`;
  if (!refresh && cache.has(key)) return cache.get(key)!;
  let dic: Dictionary;
  if (source === "bundled") dic = bundledDic(ctx.m, dictname, lang);
  else if (source === "klass") dic = await klassDic(ctx, dictname, lang);
  else {
    try {
      dic = await klassDic(ctx, dictname, lang);
    } catch (e) {
      if (lang !== "en") throw e;
      dic = bundledDic(ctx.m, dictname, lang);
      ctx.cond.warn("bundled_fallback", `SSB KLASS unreachable; using the bundled ${dictname} dictionary retrieved ${dic.vintage}.\n${(e as Error).message}`, { dictname, vintage: dic.vintage });
    }
  }
  cache.set(key, dic);
  return dic;
}

async function labelMap(ctx: ToolContext, dic: string, lang: string): Promise<Map<string, string>> {
  const m = ctx.m;
  const col = lang === "no" ? "name_no" : "name_en";
  const fromRows = (rows: Record<string, string | null>[]) => new Map(rows.map((r) => [String(r.code), String(r[col])]));
  switch (dic) {
    case "legal_form": return fromRows(m.dictionaries.legal_forms);
    case "role": return fromRows(m.dictionaries.role_types);
    case "role_group": return fromRows(m.dictionaries.role_groups);
    case "regnskap_item": return fromRows(m.dictionaries.regnskap_items);
    case "regnskap_group": return fromRows(m.dictionaries.regnskap_groups as unknown as Record<string, string | null>[]);
    case "nace": case "sector": {
      const d = await getDictionary(ctx, dic, lang);
      return new Map(d.rows.map((r) => [r.code, r.name]));
    }
    default: throw new TidybrregError("invalid_filter", `Unknown dictionary: "${dic}". Options: legal_form, nace, sector, role, role_group, regnskap_item, regnskap_group.`, { filter: "dic" });
  }
}

function apply(values: unknown[], map: Map<string, string>): (string | null)[] {
  return values.map((v) => (v === null || v === undefined ? null : (map.get(String(v)) ?? String(v))));
}

export async function labelRows(ctx: ToolContext, rows: Row[], lang: string, code: string[] = []): Promise<Row[]> {
  if (rows.length === 0) return rows;
  if (rows.some((r) => Array.isArray(r.items))) {
    rows = await Promise.all(rows.map(async (r) => (Array.isArray(r.items) ? { ...r, items: await labelRows(ctx, r.items as Row[], lang, code) } : r)));
  }
  const present = Object.keys(COLUMN_DICS).filter((c) => rows.some((r) => c in r));
  if (present.length === 0) return rows;
  const maps = new Map<string, Map<string, string>>();
  for (const dic of new Set(present.map((c) => COLUMN_DICS[c]))) maps.set(dic, await labelMap(ctx, dic, lang));
  return rows.map((r) => {
    const out: Row = {};
    for (const [k, v] of Object.entries(r)) {
      if (present.includes(k) && code.includes(k)) out[`${k}_code`] = v;
      out[k] = present.includes(k) ? apply([v], maps.get(COLUMN_DICS[k])!)[0] : v;
    }
    return out;
  });
}

export async function brreg_label(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const lang = String(args.lang ?? "en");
  const x = args.x;
  const code = Array.isArray(args.code) ? args.code.map(String) : args.code ? [String(args.code)] : [];
  if (Array.isArray(x) && x.length > 0 && typeof x[0] === "object" && x[0] !== null) {
    const rows = await labelRows(ctx, x as Row[], lang, code);
    return { kind: "table", rows, attributes: {} };
  }
  if (args.dic === undefined || args.dic === null) throw new TidybrregError("invalid_filter", "When `x` is a vector, `dic` must be provided.", { filter: "dic" });
  const values = Array.isArray(x) ? x : [x];
  const out = apply(values, await labelMap(ctx, String(args.dic), lang));
  return { kind: out.length === 1 ? "scalar" : "vector", value: out.length === 1 ? out[0] : out, attributes: {} };
}

export async function get_brreg_dic(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const d = await getDictionary(ctx, String(args.dictname ?? "nace"), String(args.lang ?? "en"), String(args.source ?? "auto"), args.refresh === true);
  return { kind: "table", rows: d.rows as unknown as Row[], columns: ["code", "name", "level"], attributes: { source: d.source, lang: d.lang, vintage: d.vintage } };
}
