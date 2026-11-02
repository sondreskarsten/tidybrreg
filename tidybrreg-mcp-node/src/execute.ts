// Dispatch a tools/call to the implementation of the named tidybrreg
// function and shape the result exactly as the R server does: a content
// text block plus structuredContent with rows, n_total, columns,
// attributes and the conditions tidybrreg's semantics raise.
import type { Manifest, ToolSpec } from "./manifest.js";
import { Http } from "./http.js";
import { Conditions, TidybrregError } from "./conditions.js";
import type { ToolContext, ToolResult } from "./tools/common.js";
import { brreg_entity, brreg_search, brreg_underenheter, brreg_children, brreg_validate } from "./tools/entities.js";
import { brreg_roles, brreg_roles_legal, brreg_konsern, brreg_signatur, brreg_prokura, brreg_regnskap } from "./tools/satellites.js";
import { brreg_updates, brreg_update_fields } from "./tools/updates.js";
import { brreg_label, get_brreg_dic } from "./tools/label.js";
import { brreg_download } from "./tools/download.js";
import type { Row } from "./parse.js";

type Impl = (ctx: ToolContext, args: Record<string, unknown>) => Promise<ToolResult>;

export const IMPLEMENTATIONS: Record<string, Impl> = {
  brreg_entity, brreg_search, brreg_underenheter, brreg_children, brreg_validate,
  brreg_roles, brreg_roles_legal, brreg_konsern, brreg_signatur, brreg_prokura, brreg_regnskap,
  brreg_updates, brreg_update_fields, brreg_label, get_brreg_dic, brreg_download,
};

export interface CallResult {
  content: { type: "text"; text: string }[];
  structuredContent: Record<string, unknown>;
  isError: boolean;
}

export function assertCoverage(m: Manifest): void {
  const missing = m.tools.map((t) => t.name).filter((n) => !(n in IMPLEMENTATIONS));
  if (missing.length > 0) {
    throw new Error(`The manifest lists tools this server does not implement: ${missing.join(", ")}. Add them to src/execute.ts.`);
  }
}

function enumCheck(tool: ToolSpec, args: Record<string, unknown>): void {
  const props = tool.inputSchema.properties ?? {};
  for (const [k, v] of Object.entries(args)) {
    const p = props[k];
    if (!p) continue;
    if (p.enum && v !== undefined && v !== null && !p.enum.includes(v)) {
      throw new TidybrregError("invalid_filter", `\`${k}\` must be one of ${p.enum.map((e) => JSON.stringify(e)).join(", ")}, not ${JSON.stringify(v)}.`, { filter: k });
    }
  }
}

export async function callTool(m: Manifest, http: Http, tool: ToolSpec, rawArgs: unknown): Promise<CallResult> {
  const args = (rawArgs ?? {}) as Record<string, unknown>;
  if (typeof args !== "object" || Array.isArray(args)) return toolError("invalid_params", "Arguments must be a JSON object.");
  const shaping = {
    limit: Math.max(1, Math.min(Math.trunc(Number(args[".limit"] ?? 200)), Number(process.env.TIDYBRREG_MCP_MAX_ROWS ?? 5000))),
    offset: Math.max(0, Math.trunc(Number(args[".offset"] ?? 0))),
    columns: Array.isArray(args[".columns"]) ? (args[".columns"] as unknown[]).map(String) : null,
    format: ["records", "csv", "markdown"].includes(String(args[".format"])) ? String(args[".format"]) : "records",
  };
  const rArgs: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(args)) if (!k.startsWith(".")) rArgs[k] = v;
  const unknown = Object.keys(rArgs).filter((k) => !(k in tool.args));
  if (unknown.length > 0) {
    return toolError("invalid_params", `Unknown argument(s): ${unknown.join(", ")}. Known: ${Object.keys(tool.args).join(", ")}`);
  }
  for (const [k, a] of Object.entries(tool.args)) {
    if (a.required && (rArgs[k] === undefined || rArgs[k] === null)) return toolError("invalid_params", `Argument \`${k}\` is required.`);
  }
  const cond = new Conditions();
  const ctx: ToolContext = { m, http, cond };
  try {
    enumCheck(tool, rArgs);
    const impl = IMPLEMENTATIONS[tool.name];
    if (!impl) throw new TidybrregError("internal", `Tool ${tool.name} is not implemented.`);
    const res = await impl(ctx, rArgs);
    return shape(tool.name, res, shaping, cond);
  } catch (e) {
    if (e instanceof TidybrregError) return toolError(e.cls, e.message, e.classes, e.fields, cond);
    const err = e as Error;
    return toolError("error", err?.message ?? String(e), ["error", "condition"], {}, cond);
  }
}

function toolError(cls: string, message: string, classes: string[] = [cls, "condition"], fields: Record<string, unknown> = {}, cond?: Conditions): CallResult {
  return {
    content: [{ type: "text", text: `Error (${cls}): ${message}` }],
    structuredContent: { error: { class: cls, classes, message, fields }, conditions: cond?.items ?? [] },
    isError: true,
  };
}

function cellType(v: unknown): string {
  if (v === null || v === undefined) return "NA";
  if (typeof v === "boolean") return "logical";
  if (typeof v === "number") return Number.isInteger(v) ? "integer" : "numeric";
  if (typeof v === "string") return /^\d{4}-\d{2}-\d{2}$/.test(v) ? "Date" : /^\d{4}-\d{2}-\d{2}T/.test(v) ? "POSIXct" : "character";
  if (Array.isArray(v) || typeof v === "object") return "list";
  return "character";
}

function columnTypes(rows: Row[], names: string[], known?: Map<string, string>): { name: string; type: string }[] {
  return names.map((name) => {
    if (known?.has(name)) return { name, type: known.get(name)! };
    const sample = rows.map((r) => r[name]).find((v) => v !== null && v !== undefined);
    return { name, type: sample === undefined ? "character" : cellType(sample) };
  });
}

export function shape(tool: string, res: ToolResult, shaping: { limit: number; offset: number; columns: string[] | null; format: string }, cond: Conditions): CallResult {
  const conditions = cond.items;
  const attributes = res.attributes ?? {};
  if (res.kind === "table") {
    const rows = res.rows ?? [];
    const n_total = rows.length;
    const allNames: string[] = [];
    for (const r of rows) for (const k of Object.keys(r)) if (!allNames.includes(k)) allNames.push(k);
    for (const c of res.columns ?? []) if (!allNames.includes(c)) allNames.push(c);
    const names = shaping.columns ? shaping.columns.filter((c) => allNames.includes(c)) : allNames;
    const slice = rows.slice(shaping.offset, shaping.offset + shaping.limit).map((r) => {
      const o: Row = {};
      for (const nme of names) o[nme] = nme in r ? r[nme] : null;
      return o;
    });
    const columns = columnTypes(rows, names, res.columnTypes);
    const text = renderRows(slice, shaping.format, n_total, shaping.offset, columns.map((c) => c.name), attributes, conditions);
    return {
      content: [{ type: "text", text }],
      structuredContent: { tool, kind: "table", rows: slice, n_rows: slice.length, n_total, offset: shaping.offset, columns, attributes, conditions },
      isError: false,
    };
  }
  const value = res.value;
  const n_total = Array.isArray(value) ? value.length : value === null || value === undefined ? 0 : 1;
  let text = JSON.stringify(value, null, 2);
  if (conditions.length > 0) text += `\n\n${renderConditions(conditions)}`;
  return {
    content: [{ type: "text", text }],
    structuredContent: { tool, kind: res.kind, value, n_total, attributes, conditions },
    isError: false,
  };
}

function fmt(v: unknown): string {
  if (v === null || v === undefined) return "";
  if (typeof v === "object") return JSON.stringify(v);
  return String(v);
}

function renderRows(rows: Row[], format: string, n_total: number, offset: number, names: string[], attributes: Record<string, unknown>, conditions: Conditions["items"]): string {
  const header = `${rows.length} of ${n_total} row${n_total === 1 ? "" : "s"} (offset ${offset}), ${names.length} column${names.length === 1 ? "" : "s"}.`;
  let body: string;
  if (format === "csv") {
    const esc = (s: string) => `"${s.replace(/"/g, '""')}"`;
    body = [names.map(esc).join(","), ...rows.map((r) => names.map((n) => esc(fmt(r[n]))).join(","))].join("\n");
  } else if (format === "markdown") {
    body = rows.length === 0 ? "(no rows)" : [
      `| ${names.join(" | ")} |`,
      `|${names.map(() => " --- |").join("")}`,
      ...rows.map((r) => `| ${names.map((n) => fmt(r[n]).replace(/\|/g, "\\|")).join(" | ")} |`),
    ].join("\n");
  } else {
    body = JSON.stringify(rows, null, 2);
  }
  const parts = [header, body];
  if (Object.keys(attributes).length > 0) parts.push(`Attributes: ${JSON.stringify(attributes)}`);
  if (conditions.length > 0) parts.push(renderConditions(conditions));
  return parts.join("\n\n");
}

function renderConditions(conditions: Conditions["items"]): string {
  return `Conditions signalled by tidybrreg:\n${conditions.map((c) => `- [${c.kind} ${c.class}] ${c.message.replace(/\n/g, " ")}`).join("\n")}`;
}
