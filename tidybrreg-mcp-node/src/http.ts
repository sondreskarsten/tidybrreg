// The request layer the manifest's `endpoints.http` describes: one user
// agent, a per-host throttle, retries on 429/503, and status-aware
// responses the tools map to tidybrreg's conditions.
import type { Manifest } from "./manifest.js";

export interface BrregResponse {
  status: number;
  headers: Headers;
  json: () => Promise<any>;
  text: () => Promise<string>;
  url: string;
}

export type Fetcher = (url: string, init?: RequestInit) => Promise<Response>;

const lastRequest = new Map<string, number>();

async function throttle(host: string, perSecond: number): Promise<void> {
  const minGap = 1000 / perSecond;
  const now = Date.now();
  const last = lastRequest.get(host) ?? 0;
  const wait = last + minGap - now;
  if (wait > 0) await new Promise((r) => setTimeout(r, wait));
  lastRequest.set(host, Date.now());
}

export function buildUrl(base: string, path: string, query: Record<string, string | number | boolean | null | undefined> = {}): string {
  const url = new URL(base.replace(/\/$/, "") + "/" + path.replace(/^\//, ""));
  for (const [k, v] of Object.entries(query)) {
    if (v === null || v === undefined) continue;
    url.searchParams.set(k, String(v));
  }
  return url.toString();
}

export class Http {
  constructor(private readonly m: Manifest, private readonly fetcher: Fetcher = (u, i) => fetch(u, i)) {}

  async get(url: string, accept?: string): Promise<BrregResponse> {
    const { http } = this.m.endpoints;
    const host = new URL(url).host;
    let attempt = 0;
    for (;;) {
      attempt += 1;
      await throttle(host, http.throttle_per_second_per_host);
      const resp = await this.fetcher(url, {
        method: "GET",
        headers: { "User-Agent": http.user_agent, Accept: accept ?? http.accept },
        redirect: "follow",
      });
      if (http.retry_statuses.includes(resp.status) && attempt < http.retry_max_tries) {
        await new Promise((r) => setTimeout(r, 500 * 2 ** (attempt - 1)));
        continue;
      }
      return { status: resp.status, headers: resp.headers, json: () => resp.json(), text: () => resp.text(), url };
    }
  }

  async head(url: string): Promise<BrregResponse> {
    const { http } = this.m.endpoints;
    await throttle(new URL(url).host, http.throttle_per_second_per_host);
    const resp = await this.fetcher(url, { method: "HEAD", headers: { "User-Agent": http.user_agent } });
    return { status: resp.status, headers: resp.headers, json: () => resp.json(), text: () => resp.text(), url };
  }

  async stream(url: string): Promise<Response> {
    const { http } = this.m.endpoints;
    await throttle(new URL(url).host, http.throttle_per_second_per_host);
    return this.fetcher(url, { method: "GET", headers: { "User-Agent": http.user_agent, Accept: "*/*" } });
  }
}

export async function errorMessages(resp: BrregResponse): Promise<string[]> {
  try {
    const body = await resp.json();
    const msgs: string[] = [];
    if (Array.isArray(body?.valideringsfeil)) {
      msgs.push(...body.valideringsfeil.map((e: any) => {
        const params = Array.isArray(e?.parametere) ? e.parametere.join(", ") : "";
        return params ? `${e.feilmelding} (${params})` : String(e.feilmelding);
      }));
    }
    if (Array.isArray(body?.validationErrors)) msgs.push(...body.validationErrors.map((e: any) => String(e.errorMessage)));
    if (body?.feilmelding && msgs.length === 0) msgs.push(String(body.feilmelding));
    if (body?.error) msgs.push(String(body.error));
    if (body?.trace) msgs.push(`trace: ${body.trace}`);
    return msgs;
  } catch {
    return [];
  }
}
