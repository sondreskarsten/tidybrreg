#!/usr/bin/env node
// tidybrreg-mcp: stdio by default (for Claude Desktop, Claude Code,
// Cursor, the OpenAI Agents SDK's MCPServerStdio), streamable HTTP with
// --http (for ChatGPT connectors, the OpenAI Responses API's remote MCP
// tool, Claude's remote MCP). Everything served comes from manifest.json.
import { createServer as createHttpServer } from "node:http";
import { randomUUID } from "node:crypto";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { createServer } from "./server.js";
import { loadManifest } from "./manifest.js";

function usage(): never {
  console.error(`tidybrreg-mcp [--http [port]] [--host 0.0.0.0] [--token TOKEN]
  stdio (default): JSON-RPC over stdin/stdout
  --http [port]  : streamable HTTP on /mcp, health on /health (port from PORT or 8080)
  --token TOKEN  : require "Authorization: Bearer TOKEN" on /mcp (or MCP_BEARER_TOKEN)
  TIDYBRREG_MCP_EXCLUDE=a,b : drop tools from the catalogue
  TIDYBRREG_OFFLINE=1       : never consult SSB KLASS; use bundled dictionaries`);
  process.exit(2);
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  let http = false;
  let port = Number(process.env.PORT ?? 8080);
  let host = "0.0.0.0";
  let token = process.env.MCP_BEARER_TOKEN ?? "";
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i];
    if (a === "--http") { http = true; if (argv[i + 1] && /^\d+$/.test(argv[i + 1])) { port = Number(argv[i + 1]); i += 1; } }
    else if (a === "--port") { port = Number(argv[++i]); http = true; }
    else if (a === "--host") host = argv[++i];
    else if (a === "--token") token = argv[++i];
    else if (a === "--help" || a === "-h") usage();
    else if (a === "--version") { console.log(loadManifest().tidybrreg.version); return; }
    else usage();
  }
  const m = loadManifest();
  if (!http) {
    const server = createServer({ manifest: m });
    await server.connect(new StdioServerTransport());
    console.error(`tidybrreg-mcp stdio: ${m.tools.length} tools from tidybrreg ${m.tidybrreg.version}`);
    return;
  }
  const httpServer = createHttpServer(async (req, res) => {
    const url = new URL(req.url ?? "/", `http://${req.headers.host ?? "localhost"}`);
    if (url.pathname === "/health" && req.method === "GET") {
      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ status: "ok", server: m.protocol.server_name, version: m.tidybrreg.version, tidybrreg: m.tidybrreg.version, tools: m.tools.length, runtime: "node" }));
      return;
    }
    if (url.pathname !== "/mcp") { res.writeHead(404, { "Content-Type": "application/json" }); res.end(JSON.stringify({ error: "not found" })); return; }
    if (token && req.headers.authorization !== `Bearer ${token}`) {
      res.writeHead(401, { "Content-Type": "application/json", "WWW-Authenticate": "Bearer" });
      res.end(JSON.stringify({ error: "unauthorized" }));
      return;
    }
    // Stateless: one server + transport per request, no session bookkeeping.
    const server = createServer({ manifest: m });
    const transport = new StreamableHTTPServerTransport({ sessionIdGenerator: undefined });
    res.on("close", () => { transport.close().catch(() => {}); server.close().catch(() => {}); });
    await server.connect(transport);
    let body: unknown = undefined;
    if (req.method === "POST") {
      const chunks: Buffer[] = [];
      for await (const c of req) chunks.push(c as Buffer);
      const txt = Buffer.concat(chunks).toString("utf8");
      try { body = txt ? JSON.parse(txt) : undefined; } catch { body = undefined; }
    }
    await transport.handleRequest(req, res, body);
  });
  httpServer.listen(port, host, () => {
    console.error(`tidybrreg-mcp http on ${host}:${port}: ${m.tools.length} tools from tidybrreg ${m.tidybrreg.version}; auth ${token ? "on" : "off"}; id ${randomUUID().slice(0, 8)}`);
  });
}

main().catch((e) => { console.error(e); process.exit(1); });
