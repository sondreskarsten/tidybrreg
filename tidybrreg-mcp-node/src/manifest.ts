// The manifest is produced by tidybrregmcp::mcp_manifest() from the
// installed tidybrreg package and committed next to this server. Nothing
// about the register is hard-coded here: tool names, schemas, descriptions,
// dictionaries, endpoint paths and the working rules all come from it.
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

export interface JsonSchema {
  type?: string;
  properties?: Record<string, JsonSchema & { enum?: unknown[]; default?: unknown; description?: string }>;
  required?: string[];
  [k: string]: unknown;
}

export interface ToolSpec {
  name: string;
  title: string;
  description: string;
  inputSchema: JsonSchema;
  outputSchema: JsonSchema;
  annotations: Record<string, unknown>;
  args: Record<string, { kind: string; required: boolean }>;
}

export interface Route {
  registry?: string;
  type?: string;
  format?: string;
  dictname?: string;
  method: string;
  path: string;
  embedded_key?: string;
}

export interface FunctionSpec {
  service?: string | null;
  kind?: string;
  routes?: Route[];
  delegates_to?: string;
  fixed?: Record<string, unknown>;
  maps?: Record<string, string>;
  query?: Record<string, string | Record<string, string | null>>;
  pagination?: Record<string, any>;
  result?: Record<string, any>;
  fixed_columns?: Record<string, string>;
  include_changes?: { param: string; value: string };
  fields?: { api_path: string; col_name: string; type: string }[];
  statements?: Record<string, string>;
  groups?: { path: string; group: string }[];
  identities?: { tolerance: number; rules: { name: string; lhs: string; plus: string[]; minus: string[]; optional: string[] }[] };
  [k: string]: unknown;
}

export interface DictRow { [k: string]: string | null }

export interface Manifest {
  manifest_version: number;
  tidybrreg: { version: string; title: string; description: string; license: string; url: string };
  protocol: { version: string; server_name: string };
  instructions: string;
  tools: ToolSpec[];
  shaping: Record<string, JsonSchema>;
  endpoints: {
    services: Record<string, string>;
    http: { user_agent: string; accept: string; throttle_per_second_per_host: number; retry_statuses: number[]; retry_max_tries: number };
    org_nr: { pattern: string; check: string };
    functions: Record<string, FunctionSpec>;
  };
  dictionaries: {
    field_dict: { api_path: string; col_name: string; type: string }[];
    legal_forms: DictRow[];
    role_types: DictRow[];
    role_groups: DictRow[];
    nace_codes: { vintage: string; classification_id: number; source_url: string; rows: DictRow[] };
    sector_codes: { vintage: string; classification_id: number; source_url: string; rows: DictRow[] };
  };
  docs: Record<string, string>;
}

let cached: Manifest | undefined;

export function manifestPath(): string {
  const here = dirname(fileURLToPath(import.meta.url));
  // dist/manifest.ts -> ../manifest.json ; src/manifest.ts -> ../manifest.json
  return join(here, "..", "manifest.json");
}

export function loadManifest(path = manifestPath()): Manifest {
  if (cached && path === manifestPath()) return cached;
  const m = JSON.parse(readFileSync(path, "utf8")) as Manifest;
  if (m.manifest_version !== 1) {
    throw new Error(`Unsupported manifest_version ${m.manifest_version}`);
  }
  if (path === manifestPath()) cached = m;
  return m;
}

export function toolByName(m: Manifest, name: string): ToolSpec | undefined {
  return m.tools.find((t) => t.name === name);
}
