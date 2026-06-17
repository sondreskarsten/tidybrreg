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
ENHETER = "https://data.brreg.no/enhetsregisteret/api/enheter"
CENSUS = {
    "konkurs": "konkurs=true",
    "tvangsavvikling": "underTvangsavviklingEllerTvangsopplosning=true",
    "avvikling": "underAvvikling=true",
    "NUF": "organisasjonsform=NUF",
}
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


def fetch_entities(name, since_iso, n_buckets, max_entities):
    sess = requests.Session()
    ents = []
    for org, href in collect(name, since_iso, n_buckets, max_entities):
        resp = sess.get(href, headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
        if resp.status_code >= 400:
            continue
        ents.append(resp.json())
    return ents


def census_enheter(per):
    sess = requests.Session()
    ents = []
    pops = {}
    tot = sess.get(f"{ENHETER}?size=1", headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
    if tot.status_code < 400:
        pops["_total"] = tot.json().get("page", {}).get("totalElements")
    for label, q in CENSUS.items():
        r = sess.get(f"{ENHETER}?{q}&size={per}", headers={"Accept": "application/json", "User-Agent": UA}, timeout=60)
        if r.status_code >= 400:
            continue
        d = r.json()
        pops[label] = d.get("page", {}).get("totalElements")
        ents.extend(d.get("_embedded", {}).get("enheter", []))
    return ents, pops


def lifecycle_state(e):
    if e.get("konkurs"):
        return "konkurs"
    if e.get("underTvangsavviklingEllerTvangsopplosning"):
        return "tvangsavvikling"
    if e.get("underAvvikling"):
        return "avvikling"
    return "ordinary"


def segment(e):
    form = (e.get("organisasjonsform") or {}).get("kode") or "UKJENT"
    return f"{form}|{lifecycle_state(e)}"


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


def tally(entities):
    counts = collections.Counter()
    types = collections.defaultdict(set)
    seg_n = collections.Counter()
    for e in entities:
        seg = segment(e)
        seg_n[seg] += 1
        for path, ty in entity_paths(e).items():
            counts[(seg, path)] += 1
            types[(seg, path)].add(ty)
    return counts, types, seg_n


def write_counts(rows, out):
    with open(out, "w", encoding="utf-8") as f:
        f.write("endpoint\tsegment\tpath\ttype\tk\tn\n")
        for ep, seg, path, ty, k, n in sorted(rows):
            f.write(f"{ep}\t{seg}\t{path}\t{ty}\t{k}\t{n}\n")


def write_pops(pops, out):
    with open(out, "w", encoding="utf-8") as f:
        f.write("state\tpopulation\n")
        for k, v in sorted(pops.items()):
            f.write(f"{k}\t{v}\n")


def run(out, since_iso, n_buckets=40, max_entities=1500, census_per=12):
    rows = []
    pops = {}
    for name in ("enhet", "underenhet"):
        ents = fetch_entities(name, since_iso, n_buckets, max_entities)
        if name == "enhet":
            cents, pops = census_enheter(census_per)
            ents = ents + cents
        counts, types, seg_n = tally(ents)
        for (seg, path), k in counts.items():
            rows.append((name, seg, path, "|".join(sorted(types[(seg, path)])), k, seg_n[seg]))
        print(f"{name}: {len(ents)} entities, {len(seg_n)} segments, {len(counts)} cells", file=sys.stderr)
    write_counts(rows, out)
    write_pops(pops, out + ".pop")
    print(f"wrote {len(rows)} cells to {out}", file=sys.stderr)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--since", required=True)
    ap.add_argument("--buckets", type=int, default=40)
    ap.add_argument("--max-entities", type=int, default=1500)
    ap.add_argument("--census-per", type=int, default=12)
    a = ap.parse_args()
    run(a.out, a.since, n_buckets=a.buckets, max_entities=a.max_entities, census_per=a.census_per)
