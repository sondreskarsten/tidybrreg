// Date and instant handling, mirroring tidybrreg's parse_brreg_date(),
// parse_brreg_instant() and format_since(): dates in ISO or DD.MM.YYYY,
// instants always UTC, `since` rendered as YYYY-MM-DDTHH:MM:SS.sssZ.
import { TidybrregError } from "./conditions.js";

export function parseBrregDate(x: unknown): string | null {
  if (x === null || x === undefined) return null;
  const s = String(x).trim();
  let m = /^(\d{4})-(\d{2})-(\d{2})/.exec(s);
  if (m) return validDate(m[1], m[2], m[3]);
  m = /^(\d{2})\.(\d{2})\.(\d{4})$/.exec(s);
  if (m) return validDate(m[3], m[2], m[1]);
  return null;
}

function validDate(y: string, mo: string, d: string): string | null {
  const t = Date.UTC(Number(y), Number(mo) - 1, Number(d));
  const dt = new Date(t);
  if (dt.getUTCFullYear() !== Number(y) || dt.getUTCMonth() !== Number(mo) - 1 || dt.getUTCDate() !== Number(d)) return null;
  return `${y}-${mo}-${d}`;
}

export function parseBrregInstant(x: unknown): string | null {
  if (x === null || x === undefined) return null;
  let s = String(x).trim();
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) s = `${s}T00:00:00`;
  const m = /^(\d{4}-\d{2}-\d{2})T(\d{2}:\d{2}:\d{2})(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$/.exec(s);
  if (!m) return null;
  const frac = m[3] ? m[3].padEnd(4, "0").slice(0, 4) : ".000";
  const iso = `${m[1]}T${m[2]}${frac}${m[4] ? m[4] : "Z"}`;
  const t = Date.parse(iso);
  if (Number.isNaN(t)) return null;
  return new Date(t).toISOString();
}

export function formatSince(since: unknown): string {
  if (since === undefined || since === null || since === "") {
    const d = new Date(Date.now() - 24 * 3600 * 1000);
    return `${d.toISOString().slice(0, 10)}T00:00:00.000Z`;
  }
  const inst = parseBrregInstant(since);
  if (!inst) {
    throw new TidybrregError("invalid_since", `\`since\` must be a Date, POSIXct, or ISO 8601 string, not "${String(since)}".`, { since });
  }
  return inst;
}

export function parseHttpDate(x: string | null | undefined): string | null {
  if (!x) return null;
  const t = Date.parse(x);
  return Number.isNaN(t) ? null : new Date(t).toISOString();
}
