import argparse
import datetime
import math
import sys

import requests
from genson import SchemaBuilder

UA = "tidybrreg-api-monitor (https://github.com/sondreskarsten/tidybrreg)"

OPPDATERINGER = {
    "enhet": "https://data.brreg.no/enhetsregisteret/api/oppdateringer/enheter",
    "underenhet": "https://data.brreg.no/enhetsregisteret/api/oppdateringer/underenheter",
}
ENTITY_LINK = {"enhet": "enhet", "underenhet": "underenhet"}


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


def probe_oppdateringer(name, since_iso, n_buckets=40, max_entities=1500):
    changed = collect(name, since_iso, n_buckets, max_entities)
    builder = SchemaBuilder()
    sess = requests.Session()
    seen = 0
    for org, href in changed:
        resp = sess.get(href, headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
        if resp.status_code >= 400:
            continue
        builder.add_object(resp.json())
        seen += 1
    print(f"{name}: {len(changed)} entities sampled since {since_iso}, {seen} fetched", file=sys.stderr)
    return builder.to_schema()


def flatten_schema(schema, prefix="", required=None, rows=None):
    if rows is None:
        rows = []
    if "anyOf" in schema:
        for sub in schema["anyOf"]:
            flatten_schema(sub, prefix, required, rows)
        return rows
    t = schema.get("type")
    types = t if isinstance(t, list) else ([t] if t is not None else [])
    if "object" in types:
        props = schema.get("properties", {})
        req = set(schema.get("required", []))
        for k, v in props.items():
            if k == "_links":
                continue
            child = f"{prefix}.{k}" if prefix else k
            flatten_schema(v, child, k in req, rows)
        return rows
    if "array" in types:
        items = schema.get("items")
        if items:
            flatten_schema(items, prefix + "[]", required, rows)
        return rows
    rows.append((prefix, "|".join(sorted(types)) if types else "null", required))
    return rows


def write_tsv(rows, out):
    ordered = sorted(set(rows))
    with open(out, "w", encoding="utf-8") as f:
        f.write("endpoint\tpath\ttype\trequired\n")
        for ep, path, ty, rq in ordered:
            f.write(f"{ep}\t{path}\t{ty}\t{'' if rq is None else str(bool(rq)).upper()}\n")


def run(out, since_iso, n_buckets=40, max_entities=1500):
    rows = []
    for name in ("enhet", "underenhet"):
        schema = probe_oppdateringer(name, since_iso, n_buckets, max_entities)
        rows.extend((name, p, ty, rq) for p, ty, rq in flatten_schema(schema))
    write_tsv(rows, out)
    print(f"wrote {len(set(rows))} rows to {out}", file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--since", required=True)
    ap.add_argument("--buckets", type=int, default=40)
    ap.add_argument("--max-entities", type=int, default=1500)
    a = ap.parse_args()
    run(a.out, a.since, n_buckets=a.buckets, max_entities=a.max_entities)
