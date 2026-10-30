import { type ToolContext, type ToolResult, fnSpec, checkOrgNr, satelliteStatus, lookupRole, lookupRoleGroup, personId, url, nz } from "./common.js";
import { parseBrregDate } from "../dates.js";
import type { Row } from "../parse.js";

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

export async function brreg_signatur(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const t = fnSpec(ctx.m, "brreg_signatur").fixed_columns?.signature_type ?? "signature";
  return satellite(ctx, "brreg_signatur", args, (raw, org) => flattenSignatur(ctx, raw, org, t));
}

export async function brreg_prokura(ctx: ToolContext, args: Record<string, unknown>): Promise<ToolResult> {
  const t = fnSpec(ctx.m, "brreg_prokura").fixed_columns?.signature_type ?? "procuration";
  return satellite(ctx, "brreg_prokura", args, (raw, org) => flattenSignatur(ctx, raw, org, t));
}
