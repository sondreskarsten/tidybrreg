import argparse
import collections
import datetime
import math
import sys

import requests

UA = "tidybrreg-api-monitor (https://github.com/sondreskarsten/tidybrreg)"

OPPDATERINGER = {
    "enhet": "https://data.brreg.no/enhetsregisteret/api/oppdateringer/enheter",
    "underenhet": "https://data.brreg.no/enhetsregisteret/api/oppdateringer/underenheter",
}
ENTITY_LINK = {"enhet": "enhet", "underenhet": "underenhet"}
TYPEMAP = {"NoneType": "null", "str": "string", "bool": "boolean", "int": "integer", "float": "number"}


def iso_z(ts):
    return ts.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


def time_buckets(since_iso, n):
    since = datetime.datetime.fromisoformat(since_iso.replace("Z", "+00:00"))
    now = datetime.datetime.now(datetime.timezone.utc)
    if n <= 1:
        return [since]
    span = (now - since) / n
    return [since + span * i for i in range(n)]


def collect(name, since_iso, n_buckets, max_entities):
    feed = OPPDATERINGER[name]
    sess = requests.Session()
    hrefs = {}
    per = max(1, math.ceil(max_entities / n_buckets))
    for ts in time_buckets(since_iso, n_buckets):
        if len(hrefs) >= max_entities:
            break
        params = {"dato": iso_z(ts), "size": 200}
        got = 0
        for _ in range(6):
            r = sess.get(feed, params=params, headers={"Accept": "application/json", "User-Agent": UA}, timeout=120)
            r.raise_for_status()
            emb = r.json().get("_embedded", {})
            key = next(iter(emb), None)
            rows = emb.get(key, []) if key else []
            if not rows:
                break
            last_id = None
            for e in rows:
                last_id = e.get("oppdateringsid")
                if e.get("endringstype") in ("Ny", "Endring"):
                    org = e.get("organisasjonsnummer")
                    href = e.get("_links", {}).get(ENTITY_LINK[name], {}).get("href")
                    if org and href and org not in hrefs:
                        hrefs[org] = href
                        got += 1
                        if got >= per or len(hrefs) >= max_entities:
                            break
            if got >= per or len(hrefs) >= max_entities or last_id is None:
                break
            params = {"oppdateringsid": last_id + 1, "size": 200}
    return list(hrefs.items())[:max_entities]


def entity_paths(x, prefix="", out=None):
    if out is None:
        out = {}
    if isinstance(x, dict):
        for k, v in x.items():
            if k == "_links":
                continue
            child = f"{prefix}.{k}" if prefix else k
            entity_paths(v, child, out)
    elif isinstance(x, list):
        if x:
            for item in x:
                entity_paths(item, prefix + "[]", out)
    else:
        out[prefix] = TYPEMAP.get(type(x).__name__, type(x).__name__)
    return out


def probe_period(name, since_iso, n_buckets, max_entities):
    changed = collect(name, since_iso, n_buckets, max_entities)
    sess = requests.Session()
    counts = collections.Counter()
    types = collections.defaultdict(set)
    n = 0
    for org, href in changed:
        resp = sess.get(href, headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
        if resp.status_code >= 400:
            continue
        for path, ty in entity_paths(resp.json()).items():
            counts[path] += 1
            types[path].add(ty)
        n += 1
    print(f"{name}: {len(changed)} entities sampled since {since_iso}, {n} fetched, {len(counts)} fields", file=sys.stderr)
    return counts, types, n


def write_counts(rows, out):
    with open(out, "w", encoding="utf-8") as f:
        f.write("endpoint\tpath\ttype\tk\tn\n")
        for ep, path, ty, k, n in sorted(rows):
            f.write(f"{ep}\t{path}\t{ty}\t{k}\t{n}\n")


def run(out, since_iso, n_buckets=40, max_entities=1500):
    rows = []
    for name in ("enhet", "underenhet"):
        counts, types, n = probe_period(name, since_iso, n_buckets, max_entities)
        for path, k in counts.items():
            rows.append((name, path, "|".join(sorted(types[path])), k, n))
    write_counts(rows, out)
    print(f"wrote {len(rows)} rows to {out}", file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--since", required=True)
    ap.add_argument("--buckets", type=int, default=40)
    ap.add_argument("--max-entities", type=int, default=1500)
    a = ap.parse_args()
    run(a.out, a.since, n_buckets=a.buckets, max_entities=a.max_entities)
