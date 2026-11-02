// Fails when the committed manifest.json differs from what the installed
// tidybrreg + tidybrregmcp produce, so the Node server can never drift
// from the R package. Requires R with both packages installed.
import { execFileSync } from "node:child_process";
import { readFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const committed = join(root, "manifest.json");
const fresh = join(mkdtempSync(join(tmpdir(), "tidybrreg-manifest-")), "manifest.json");
execFileSync("Rscript", ["-e", `tidybrregmcp::mcp_manifest(${JSON.stringify(fresh)})`], { stdio: "inherit" });
const a = readFileSync(committed, "utf8");
const b = readFileSync(fresh, "utf8");
if (a !== b) {
  console.error(`manifest.json is stale: regenerate it with\n  Rscript -e 'tidybrregmcp::mcp_manifest("tidybrreg-mcp-node/manifest.json")'\nand commit the result.`);
  const la = a.split("\n"), lb = b.split("\n");
  for (let i = 0; i < Math.max(la.length, lb.length); i += 1) {
    if (la[i] !== lb[i]) { console.error(`first difference at line ${i + 1}:\n  committed: ${la[i]}\n  fresh:     ${lb[i]}`); break; }
  }
  process.exit(1);
}
console.log("manifest.json is current");
