// The two tidybrreg parsing rules, ported: flatten nested JSON to
// dot-notation keys (arrays collapsed with "\n", arrays of objects
// serialised), rename through field_dict emitting observed fields only,
// strip HAL links at any depth, and coerce dictionary types with
// failures reported rather than fatal.
import type { Manifest } from "./manifest.js";
import { parseBrregDate } from "./dates.js";

export type Cell = string | number | boolean | null;
export type Row = Record<string, Cell | Cell[] | Record<string, unknown>[] | Record<string, unknown> | null>;

export function toSnake(x: string): string {
  return x.replace(/([a-z0-9])([A-Z])/g, "$1_$2").replace(/\./g, "_").toLowerCase();
}

export function isHalLinkPath(path: string): boolean {
  return path.split(".").some((p) => p === "_links" || p === "links");
}

export function collapseObserved(val: unknown): string | null {
  if (val === null || val === undefined) return null;
  if (Array.isArray(val)) {
    if (val.length === 0) return null;
    if (val.every((v) => v === null || v === undefined)) return null;
    if (val.some((v) => v !== null && typeof v === "object")) return JSON.stringify(val);
    return val.map((v) => String(v)).join("\n");
  }
  if (typeof val === "object") return JSON.stringify(val);
  return String(val);
}

export function flattenJson(x: Record<string, unknown>, prefix = ""): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(x)) {
    const full = prefix ? `${prefix}.${k}` : k;
    if (v !== null && typeof v === "object" && !Array.isArray(v)) {
      Object.assign(out, flattenJson(v as Record<string, unknown>, full));
    } else if (Array.isArray(v)) {
      out[full] = collapseObserved(v);
    } else {
      out[full] = v;
    }
  }
  return out;
}

export interface ParseProblem { column: string; row: number; expected: string; actual: string; n_failed: number }

export function parseLogical(x: unknown): boolean | null {
  if (typeof x === "boolean") return x;
  if (x === null || x === undefined) return null;
  const s = String(x).trim().toLowerCase();
  if (["true", "t", "ja", "1"].includes(s)) return true;
  if (["false", "f", "nei", "0"].includes(s)) return false;
  return null;
}

export function coerceValue(x: unknown, type: string): { value: Cell; failed: boolean } {
  const present = !(x === null || x === undefined || (typeof x === "string" && x.trim() === ""));
  if (!present) return { value: null, failed: false };
  switch (type) {
    case "Date": {
      const v = parseBrregDate(x);
      return { value: v, failed: v === null };
    }
    case "integer": {
      const s = String(x).trim();
      if (!/^-?\d+(\.0+)?$/.test(s)) return { value: null, failed: true };
      return { value: Number.parseInt(s, 10), failed: false };
    }
    case "numeric": {
      const n = Number(String(x).trim());
      return Number.isFinite(n) ? { value: n, failed: false } : { value: null, failed: true };
    }
    case "logical": {
      const v = parseLogical(x);
      return { value: v, failed: v === null };
    }
    case "character":
      return { value: typeof x === "string" ? x : String(x), failed: false };
    default:
      return { value: x as Cell, failed: false };
  }
}

export function dictTypeMap(m: Manifest): Map<string, string> {
  const types = new Map<string, string>();
  for (const d of m.dictionaries.field_dict) if (!types.has(d.col_name)) types.set(d.col_name, d.type);
  return types;
}

export type FieldMap = { api_path: string; col_name: string; type: string }[];

/** Rename one flattened record through field_dict; observed fields only. */
export function renameFromDict(m: Manifest, flat: Record<string, unknown>): { row: Row; types: Map<string, string> } {
  return renameThrough(m.dictionaries.field_dict, flat);
}

/** The same rule with any field map (field_dict, or a function's `fields` in the endpoint spec). */
export function renameThrough(dict: FieldMap, flat: Record<string, unknown>): { row: Row; types: Map<string, string> } {
  const row: Row = {};
  const types = new Map<string, string>();
  const mapped = new Set<string>();
  const keys = Object.keys(flat).filter((k) => !isHalLinkPath(k));
  for (const d of dict) {
    if (!keys.includes(d.api_path)) continue;
    if (d.col_name in row) continue;
    row[d.col_name] = scalarise(flat[d.api_path]);
    types.set(d.col_name, d.type);
    mapped.add(d.api_path);
  }
  const taken = new Set(Object.keys(row));
  for (const k of keys) {
    if (mapped.has(k)) continue;
    let name = toSnake(k);
    if (taken.has(name)) {
      let i = 1;
      while (taken.has(`${name}_${i}`)) i += 1;
      name = `${name}_${i}`;
    }
    taken.add(name);
    row[name] = scalarise(flat[k]);
    const d = dict.find((e) => e.api_path === k);
    if (d) types.set(name, d.type);
  }
  return { row, types };
}

function scalarise(v: unknown): Cell {
  if (v === null || v === undefined) return null;
  if (Array.isArray(v)) return collapseObserved(v);
  if (typeof v === "object") return JSON.stringify(v);
  return v as Cell;
}

export interface ParsedTable { rows: Row[]; problems: ParseProblem[]; types: Map<string, string> }

/** Coerce dictionary-typed columns across a set of rows, collecting problems. */
export function coerceRows(rows: Row[], types: Map<string, string>): ParseProblem[] {
  const problems: ParseProblem[] = [];
  for (const [col, type] of types) {
    const failed: { row: number; actual: string }[] = [];
    rows.forEach((r, i) => {
      if (!(col in r)) return;
      const { value, failed: f } = coerceValue(r[col], type);
      if (f) failed.push({ row: i + 1, actual: String(r[col]) });
      r[col] = value;
    });
    if (failed.length > 0) {
      for (const f of failed.slice(0, 20)) problems.push({ column: col, row: f.row, expected: type, actual: f.actual, n_failed: failed.length });
    }
  }
  return problems;
}

export function parseEntity(m: Manifest, raw: Record<string, unknown>): ParsedTable {
  const { row, types } = renameFromDict(m, flattenJson(raw));
  const rows = [row];
  const problems = coerceRows(rows, types);
  return { rows, problems, types };
}

export function parseEntities(m: Manifest, raws: Record<string, unknown>[]): ParsedTable {
  const rows: Row[] = [];
  const types = new Map<string, string>();
  for (const raw of raws) {
    const r = renameFromDict(m, flattenJson(raw));
    rows.push(r.row);
    for (const [k, v] of r.types) if (!types.has(k)) types.set(k, v);
  }
  const problems = coerceRows(rows, types);
  return { rows, problems, types };
}

export function emptyEntities(): Row[] {
  return [];
}

export const EMPTY_ENTITY_COLUMNS = ["org_nr", "name", "legal_form"];
