import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import {
  CallToolRequestSchema, ListResourcesRequestSchema, ListToolsRequestSchema,
  ReadResourceRequestSchema, ListResourceTemplatesRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { loadManifest, type Manifest } from "./manifest.js";
import { Http, type Fetcher } from "./http.js";
import { callTool, assertCoverage } from "./execute.js";

export interface ServerOptions {
  manifest?: Manifest;
  fetcher?: Fetcher;
  exclude?: string[];
}

export function excludedFromEnv(): string[] {
  return (process.env.TIDYBRREG_MCP_EXCLUDE ?? "").split(",").map((s) => s.trim()).filter(Boolean);
}

export function createServer(opts: ServerOptions = {}): Server {
  const m = opts.manifest ?? loadManifest();
  assertCoverage(m);
  const exclude = opts.exclude ?? excludedFromEnv();
  const tools = m.tools.filter((t) => !exclude.includes(t.name));
  const http = new Http(m, opts.fetcher);
  const pkgVersion = m.tidybrreg.version;

  const server = new Server(
    { name: m.protocol.server_name, version: pkgVersion, title: `tidybrreg ${pkgVersion}: Norway's business registry (Enhetsregisteret)` },
    { capabilities: { tools: { listChanged: false }, resources: { subscribe: false, listChanged: false } }, instructions: m.instructions },
  );

  server.setRequestHandler(ListToolsRequestSchema, async () => ({
    tools: tools.map((t) => ({
      name: t.name, title: t.title, description: t.description,
      inputSchema: t.inputSchema as any, outputSchema: t.outputSchema as any, annotations: t.annotations as any,
    })),
  }));

  server.setRequestHandler(CallToolRequestSchema, async (req) => {
    const tool = tools.find((t) => t.name === req.params.name);
    if (!tool) {
      return { content: [{ type: "text", text: `Unknown tool: ${req.params.name}` }], isError: true };
    }
    const r = await callTool(m, http, tool, req.params.arguments);
    return { content: r.content, structuredContent: r.structuredContent, isError: r.isError };
  });

  const resources = buildResources(m);
  server.setRequestHandler(ListResourcesRequestSchema, async () => ({
    resources: resources.map((r) => ({ uri: r.uri, name: r.name, title: r.title, mimeType: r.mimeType, description: r.description })),
  }));
  server.setRequestHandler(ListResourceTemplatesRequestSchema, async () => ({ resourceTemplates: [] }));
  server.setRequestHandler(ReadResourceRequestSchema, async (req) => {
    const r = resources.find((x) => x.uri === req.params.uri);
    if (!r) throw new Error(`Resource not found: ${req.params.uri}`);
    return { contents: [{ uri: r.uri, mimeType: r.mimeType, text: r.read() }] };
  });

  return server;
}

interface Resource { uri: string; name: string; title: string; mimeType: string; description?: string; read: () => string }

export function buildResources(m: Manifest): Resource[] {
  const out: Resource[] = [];
  for (const [topic, md] of Object.entries(m.docs)) {
    const title = md.split("\n")[0].replace(/^# [^:]+: /, "");
    out.push({ uri: `tidybrreg://docs/${topic}`, name: `docs/${topic}`, title, mimeType: "text/markdown", description: `Help page ${topic} of tidybrreg`, read: () => md });
  }
  for (const ds of ["field_dict", "legal_forms", "role_types", "role_groups"] as const) {
    out.push({ uri: `tidybrreg://data/${ds}`, name: `data/${ds}`, title: `Bundled dataset ${ds}`, mimeType: "application/json", description: `Reference table ${ds} as JSON rows`, read: () => JSON.stringify(m.dictionaries[ds], null, 2) });
  }
  for (const ds of ["nace_codes", "sector_codes"] as const) {
    out.push({ uri: `tidybrreg://data/${ds}`, name: `data/${ds}`, title: `Bundled dictionary ${ds} (vintage ${m.dictionaries[ds].vintage})`, mimeType: "application/json", description: `SSB KLASS fallback dictionary as JSON rows`, read: () => JSON.stringify(m.dictionaries[ds].rows, null, 2) });
  }
  out.push({ uri: "tidybrreg://endpoints", name: "endpoints", title: "Endpoint contract (inst/extdata/endpoints.json)", mimeType: "application/json", read: () => JSON.stringify(m.endpoints, null, 2) });
  out.push({ uri: "tidybrreg://manifest", name: "manifest", title: `tidybrreg MCP manifest ${m.tidybrreg.version}`, mimeType: "application/json", read: () => JSON.stringify({ ...m, docs: Object.keys(m.docs) }, null, 2) });
  return out;
}
