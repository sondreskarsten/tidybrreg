"""Scan the brreg-json-fetcher data release: every leaf path of every filing,
its JSON types, counts and ranges; empty objects and arrays; accounting
identity violations; and a curated sample of real filings covering every
observed path shape. Writes population_paths.json, identities.json and
sample_filings.json next to the release files."""
import csv, json, sys, random, collections, glob, os
csv.field_size_limit(1 << 30)
release = sys.argv[1]
out = sys.argv[2]
random.seed(20261030)

paths = collections.defaultdict(lambda: {"n": 0, "types": collections.Counter(), "min": None, "max": None, "examples": collections.Counter()})
shapes = collections.Counter()
shape_example = {}
n = 0
identity_fail = collections.Counter()
identity_checked = collections.Counter()
per_filing_fail = collections.Counter()
top_keys = collections.Counter()
sample = []
rare_sample = []
meta_cols = None

def walk(v, prefix, leaves):
    if isinstance(v, dict):
        if not v:
            leaves.append((prefix, "empty_object", v)); return
        for k, x in v.items():
            walk(x, f"{prefix}.{k}" if prefix else k, leaves)
    elif isinstance(v, list):
        leaves.append((prefix, "array", v))
    else:
        leaves.append((prefix, type(v).__name__ if v is not None else "null", v))

def g(d, *ks):
    for k in ks:
        if not isinstance(d, dict) or k not in d: return None
        d = d[k]
    return d if isinstance(d, (int, float)) and not isinstance(d, bool) else None

IDENTITIES = {
 "assets_eq_equity_liabilities": (("eiendeler","sumEiendeler"), [("egenkapitalGjeld","sumEgenkapitalGjeld")], []),
 "equity_plus_liabilities": (("egenkapitalGjeld","sumEgenkapitalGjeld"), [("egenkapitalGjeld","egenkapital","sumEgenkapital"),("egenkapitalGjeld","gjeldOversikt","sumGjeld")], []),
 "equity_components": (("egenkapitalGjeld","egenkapital","sumEgenkapital"), [("egenkapitalGjeld","egenkapital","innskuttEgenkapital","sumInnskuttEgenkaptial"),("egenkapitalGjeld","egenkapital","opptjentEgenkapital","sumOpptjentEgenkapital")], []),
 "liabilities_components": (("egenkapitalGjeld","gjeldOversikt","sumGjeld"), [("egenkapitalGjeld","gjeldOversikt","kortsiktigGjeld","sumKortsiktigGjeld"),("egenkapitalGjeld","gjeldOversikt","langsiktigGjeld","sumLangsiktigGjeld")], []),
 "assets_components": (("eiendeler","sumEiendeler"), [("eiendeler","omloepsmidler","sumOmloepsmidler"),("eiendeler","anleggsmidler","sumAnleggsmidler")], []),
 "operating_result": (("resultatregnskapResultat","driftsresultat","driftsresultat"), [("resultatregnskapResultat","driftsresultat","driftsinntekter","sumDriftsinntekter")], [("resultatregnskapResultat","driftsresultat","driftskostnad","sumDriftskostnad")]),
 "net_financial": (("resultatregnskapResultat","finansresultat","nettoFinans"), [("resultatregnskapResultat","finansresultat","finansinntekt","sumFinansinntekter")], [("resultatregnskapResultat","finansresultat","finanskostnad","sumFinanskostnad")]),
 "pre_tax_result": (("resultatregnskapResultat","ordinaertResultatFoerSkattekostnad"), [("resultatregnskapResultat","driftsresultat","driftsresultat"),("resultatregnskapResultat","finansresultat","nettoFinans")], []),
 "net_income": (("resultatregnskapResultat","aarsresultat"), [("resultatregnskapResultat","ordinaertResultatFoerSkattekostnad"),("resultatregnskapResultat","ekstraordinaerePoster")], [("resultatregnskapResultat","ordinaertResultatSkattekostnad"),("resultatregnskapResultat","skattekostnadEkstraordinaertResultat")]),
}

def check_identities(f):
    fails = []
    for name, (lhs, plus, minus) in IDENTITIES.items():
        l = g(f, *lhs)
        terms = [g(f, *p) for p in plus] + [g(f, *m) for m in minus]
        if l is None or all(t is None for t in terms): continue
        identity_checked[name] += 1
        rhs = sum(t for t in [g(f, *p) for p in plus] if t is not None) - sum(t for t in [g(f, *m) for m in minus] if t is not None)
        if abs(l - rhs) > 0: 
            fails.append(name); identity_fail[name] += 1
    return fails

seen_leaf_sets = collections.Counter()
for fn in sorted(glob.glob(os.path.join(release, "accounts-*.csv"))):
    with open(fn, newline="", encoding="utf-8") as fh:
        r = csv.DictReader(fh)
        if meta_cols is None: meta_cols = [c for c in r.fieldnames if not c.startswith("_meta.")]
        for row in r:
            f = json.loads(row["_meta.filing_json"])
            n += 1
            top_keys.update(f.keys())
            leaves = []
            walk(f, "", leaves)
            leafset = tuple(sorted(p for p, t, v in leaves))
            key = (leafset, tuple(sorted((p, t) for p, t, v in leaves if t in ("empty_object","array","null","str") and not p.startswith(("journalnr","regnskapstype","valuta","oppstillingsplan","virksomhet","regnskapsperiode","regnkapsprinsipper.regnskapsregler")))))
            shapes[key] += 1
            if key not in shape_example: shape_example[key] = f
            for p, t, v in leaves:
                e = paths[p]; e["n"] += 1; e["types"][t] += 1
                if t in ("int","float"):
                    e["min"] = v if e["min"] is None else min(e["min"], v); e["max"] = v if e["max"] is None else max(e["max"], v)
                elif t in ("str","bool") and len(e["examples"]) < 12: e["examples"][str(v)] += 1
                elif t == "empty_object" and len(e["examples"]) < 3: e["examples"]["{}"] += 1
            fails = check_identities(f)
            per_filing_fail[len(fails)] += 1
            if n % 200000 == 0: print(n, file=sys.stderr)
            if random.random() < 0.004: sample.append(f)

csv_leaf_cols = set(meta_cols)
json_paths = set(paths)
report = {
  "filings": n, "top_level_keys": top_keys,
  "paths": {p: {"n": e["n"], "share": round(e["n"]/n, 6), "types": e["types"], "min": e["min"], "max": e["max"], "examples": e["examples"]} for p, e in sorted(paths.items())},
  "csv_columns_not_in_json_paths": sorted(csv_leaf_cols - json_paths),
  "json_paths_not_in_csv_columns": sorted(json_paths - csv_leaf_cols),
  "distinct_shapes": len(shapes),
  "identities": {k: {"checked": identity_checked[k], "failed": identity_fail[k], "share_failed": round(identity_fail[k]/identity_checked[k], 6) if identity_checked[k] else None} for k in IDENTITIES},
  "filings_by_failed_identity_count": dict(sorted(per_filing_fail.items())),
}
json.dump(report, open(os.path.join(out, "population_paths.json"), "w"), indent=1, ensure_ascii=False, default=lambda o: dict(o))
curated = [shape_example[k] for k in shapes]
json.dump(curated, open(os.path.join(out, "shape_examples.json"), "w"), ensure_ascii=False)
json.dump(sample, open(os.path.join(out, "sample_filings.json"), "w"), ensure_ascii=False)
print(json.dumps({"filings": n, "paths": len(paths), "shapes": len(shapes), "sample": len(sample), "csv_only": report["csv_columns_not_in_json_paths"], "json_only": report["json_paths_not_in_csv_columns"], "identities": report["identities"], "by_fail_count": report["filings_by_failed_identity_count"]}, indent=1))
