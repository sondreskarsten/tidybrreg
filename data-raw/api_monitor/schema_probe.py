import argparse
import gzip
import sys
import time

import requests
import ijson
from genson import SchemaBuilder

UA = "tidybrreg-api-monitor (https://github.com/sondreskarsten/tidybrreg)"

BULK = {
    "enhet": (
        "https://data.brreg.no/enhetsregisteret/api/enheter/lastned",
        "application/vnd.brreg.enhetsregisteret.enhet.v2+gzip",
    ),
    "underenhet": (
        "https://data.brreg.no/enhetsregisteret/api/underenheter/lastned",
        "application/vnd.brreg.enhetsregisteret.underenhet.v2+gzip",
    ),
    "roller": (
        "https://data.brreg.no/enhetsregisteret/api/roller/totalbestand",
        "application/vnd.brreg.enhetsregisteret.rolleoversikt.v2+gzip",
    ),
}

FULLMAKT = {
    "signatur": "https://data.brreg.no/fullmakt/enheter/{}/signatur",
    "prokura": "https://data.brreg.no/fullmakt/enheter/{}/prokura",
}


def probe_bulk(name, limit=0, stride=1, collect_orgnrs=None, sample_step=0):
    url, accept = BULK[name]
    t0 = time.time()
    builder = SchemaBuilder()
    seen = 0
    read = 0
    with requests.get(url, headers={"Accept": accept, "User-Agent": UA}, stream=True, timeout=1800) as r:
        r.raise_for_status()
        r.raw.decode_content = False
        gz = gzip.GzipFile(fileobj=r.raw)
        for obj in ijson.items(gz, "item", use_float=True):
            read += 1
            if stride > 1 and read % stride != 0:
                continue
            builder.add_object(obj)
            seen += 1
            if collect_orgnrs is not None and sample_step and seen % sample_step == 0:
                org = obj.get("organisasjonsnummer")
                if org:
                    collect_orgnrs.append(org)
            if limit and seen >= limit:
                break
    print(f"{name}: read {read} added {seen} in {time.time()-t0:.0f}s", file=sys.stderr)
    return builder.to_schema()


def probe_fullmakt(name, orgnrs):
    url = FULLMAKT[name]
    builder = SchemaBuilder()
    sess = requests.Session()
    seen = 0
    for org in orgnrs:
        resp = sess.get(url.format(org), headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
        if resp.status_code >= 400:
            continue
        builder.add_object(resp.json())
        seen += 1
    print(f"{name}: sampled {len(orgnrs)} orgnrs, {seen} with data", file=sys.stderr)
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
        if not props:
            rows.append((prefix, "object", required))
        for k, v in props.items():
            child = f"{prefix}.{k}" if prefix else k
            flatten_schema(v, child, k in req, rows)
        return rows
    if "array" in types:
        items = schema.get("items")
        if items:
            flatten_schema(items, prefix + "[]", required, rows)
        else:
            rows.append((prefix + "[]", "array", required))
        return rows
    rows.append((prefix, "|".join(sorted(types)) if types else "null", required))
    return rows


def write_tsv(rows, out):
    ordered = sorted(set(rows))
    with open(out, "w", encoding="utf-8") as f:
        f.write("endpoint\tpath\ttype\trequired\n")
        for ep, path, ty, rq in ordered:
            f.write(f"{ep}\t{path}\t{ty}\t{'' if rq is None else str(bool(rq)).upper()}\n")


def run(out, limit=0, stride=1, fullmakt_step=3000):
    rows = []
    orgnrs = []
    for name in ("enhet", "underenhet", "roller"):
        schema = probe_bulk(
            name,
            limit=limit,
            stride=stride,
            collect_orgnrs=orgnrs if name == "enhet" else None,
            sample_step=fullmakt_step if name == "enhet" else 0,
        )
        rows.extend((name, p, ty, rq) for p, ty, rq in flatten_schema(schema))
    for name in ("signatur", "prokura"):
        schema = probe_fullmakt(name, orgnrs)
        rows.extend((name, p, ty, rq) for p, ty, rq in flatten_schema(schema))
    write_tsv(rows, out)
    print(f"wrote {len(set(rows))} rows to {out}", file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--stride", type=int, default=1)
    ap.add_argument("--fullmakt-step", type=int, default=3000)
    a = ap.parse_args()
    run(a.out, limit=a.limit, stride=a.stride, fullmakt_step=a.fullmakt_step)
