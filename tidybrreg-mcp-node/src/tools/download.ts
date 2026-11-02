// brreg_download without R: the gzipped payload is fetched into the
// cache directory with the same refresh/cache contract, and the result is
// the path. A 1-million-row tibble cannot travel over MCP, so
// type_output = "tibble" answers with the path plus a short preview of
// the JSON array and a message saying so. The bulk is JSON only, as in
// tidybrreg.
import { createWriteStream, existsSync, mkdirSync, readFileSync, statSync, unlinkSync, writeFileSync, createReadStream } from "node:fs";
import { homedir, tmpdir } from "node:os";
import { join } from "node:path";
import { pipeline } from "node:stream/promises";
import { Readable } from "node:stream";
import { createGunzip } from "node:zlib";
import { type ToolContext, type ToolResult, fnSpec } from "./common.js";
import { TidybrregError } from "../conditions.js";
import { parseHttpDate } from "../dates.js";
import { renameFromDict, coerceRows, flattenJson, type Row } from "../parse.js";

export function cacheDir(): string {
  const env = process.env.TIDYBRREG_CACHE_DIR;
  if (env) return env;
  const xdg = process.env.XDG_CACHE_HOME ?? join(homedir(), ".cache");
  return join(xdg, "R", "tidybrreg");
}

interface Meta { url: string; etag: string | null; last_modified: string | null; downloaded_at: string; path: string }

async function cacheIsCurrent(ctx: ToolContext, urlStr: string, metaFile: string): Promise<boolean> {
  if (!existsSync(metaFile)) return false;
  let meta: Meta;
  try { meta = JSON.parse(readFileSync(metaFile, "utf8")); } catch { return false; }
  let resp;
  try { resp = await ctx.http.head(urlStr); } catch { return false; }
  const checks: boolean[] = [];
  const etag = resp.headers.get("etag");
  const lm = parseHttpDate(resp.headers.get("last-modified"));
  if (etag && meta.etag) checks.push(etag === meta.etag);
  if (lm && meta.last_modified) checks.push(lm === meta.last_modified);
  return checks.length > 0 && checks.every(Boolean);
}

/** The first `n` elements of a gzipped JSON array, read without inflating the whole file (tidybrreg's read_json_head). */
export async function readJsonHead(file: string, n: number): Promise<unknown[]> {
  const stream = createReadStream(file).pipe(createGunzip());
  const parts: string[] = [];
  let depth = 0; let inString = false; let escaped = false; let closed = 0; let done = false;
  for await (const chunk of stream) {
    const text = (chunk as Buffer).toString("utf8");
    let cut = -1;
    for (let i = 0; i < text.length; i += 1) {
      const c = text[i];
      if (inString) {
        if (escaped) escaped = false;
        else if (c === "\\") escaped = true;
        else if (c === '"') inString = false;
      } else if (c === '"') inString = true;
      else if (c === "{") depth += 1;
      else if (c === "}") { depth -= 1; if (depth === 0) { closed += 1; if (closed >= n) { cut = i + 1; break; } } }
    }
    if (cut >= 0) { parts.push(text.slice(0, cut)); done = true; break; }
    parts.push(text);
  }
  if (!done && parts.length === 0) return [];
  const body = parts.join("").replace(/^\s*\[/, "").replace(/\]\s*$/, "");
  return body.trim() === "" ? [] : (JSON.parse(`[${body}]`) as unknown[]);
}

async function previewJson(ctx: ToolContext, file: string, n: number): Promise<Row[]> {
  const raws = await readJsonHead(file, n);
  const rows: Row[] = [];
  const types = new Map<string, string>();
  for (const raw of raws) {
    const r = renameFromDict(ctx.m, flattenJson(raw as Record<string, unknown>));
    rows.push(r.row);
    for (const [k, v] of r.types) if (!types.has(k)) types.set(k, v);
  }
  coerceRows(rows, types);
  return rows;
}

export async function brreg_download(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const spec = fnSpec(ctx.m, "brreg_download");
  const type = String(args.type ?? "enheter");
  const refresh = args.refresh ?? false;
  const cache = args.cache ?? true;
  const type_output = String(args.type_output ?? "tibble");
  if (!(refresh === true || refresh === false || refresh === "auto")) {
    throw new TidybrregError("invalid_filter", '`refresh` must be TRUE, FALSE, or "auto".', { registry: type, filter: "refresh" });
  }
  if (!(cache === true || cache === false)) throw new TidybrregError("invalid_filter", "`cache` must be TRUE or FALSE.", { registry: type, filter: "cache" });
  if (!(spec.output_modes as string[]).includes(type_output)) {
    throw new TidybrregError("invalid_filter", `type_output must be one of ${(spec.output_modes as string[]).join(", ")}.`, { registry: type, filter: "type_output" });
  }
  const route = spec.routes!.find((r) => r.type === type);
  if (!route) throw new TidybrregError("invalid_filter", `No bulk route for ${type}.`, { registry: type, filter: "type" });
  const urlStr = ctx.m.endpoints.services.enhetsregisteret.replace(/\/$/, "") + route.path;

  let file: string;
  let metaFile: string | null = null;
  let needs = true;
  if (cache) {
    const dir = cacheDir();
    mkdirSync(dir, { recursive: true });
    file = join(dir, `${type}_bulk.json.gz`);
    metaFile = `${file}.meta.json`;
    needs = !existsSync(file) || refresh === true;
    if (refresh === "auto" && existsSync(file)) needs = !(await cacheIsCurrent(ctx, urlStr, metaFile));
  } else {
    file = join(tmpdir(), `${type}_bulk_${process.pid}_${Date.now()}.json.gz`);
  }

  let meta: Meta;
  if (needs) {
    const resp = await ctx.http.stream(urlStr);
    if (!resp.ok || !resp.body) throw new TidybrregError("http", `Norwegian Business Registry API error: HTTP ${resp.status} for ${route.path}.`, { endpoint: route.path, status: resp.status, messages: [] });
    await pipeline(Readable.fromWeb(resp.body as any), createWriteStream(file));
    meta = { url: urlStr, etag: resp.headers.get("etag"), last_modified: parseHttpDate(resp.headers.get("last-modified")), downloaded_at: new Date().toISOString(), path: file };
    if (metaFile) writeFileSync(metaFile, JSON.stringify(meta, null, 2));
    ctx.cond.inform(`Downloaded ${(statSync(file).size / 1024 ** 2).toFixed(1)} MB.`);
  } else {
    try { meta = JSON.parse(readFileSync(metaFile!, "utf8")); } catch { meta = { url: urlStr, etag: null, last_modified: null, downloaded_at: statSync(file).mtime.toISOString(), path: file }; }
    ctx.cond.inform(`Using cached file (${(statSync(file).size / 1024 ** 2).toFixed(1)} MB, ${statSync(file).mtime.toISOString()}).`);
  }

  if (type_output === "path") return { kind: "scalar", value: file, attributes: { brreg_download: meta } };

  const preview: Row[] = type === "roller" ? [] : await previewJson(ctx, file, 20);
  ctx.cond.inform(`This server runs without R: the full ${type} extract is at ${file}; the rows returned are a ${preview.length}-row preview. Parse the file with tidybrreg::brreg_download() in R, or any JSON reader, for the complete table.`);
  const attributes: Record<string, unknown> = { brreg_download: meta, path: file, preview: true };
  if (!cache) { try { unlinkSync(file); } catch { /* ignore */ } }
  return { kind: "table", rows: preview, columns: ["org_nr", "name", "legal_form"], attributes };
}
