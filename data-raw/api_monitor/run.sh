#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
out="${TMPDIR:-/tmp}/tidybrreg_counts.tsv"
f=data-raw/api_monitor/state/periods.tsv
if [ -s "$f" ]; then
  since=$(awk -F'\t' 'NR>1{print $4}' "$f" | sort | tail -1)
else
  prev_ver=$(grep -E '^# tidybrreg' NEWS.md | sed -n 2p | awk '{print $3}')
  since=$(git log -S"Version: ${prev_ver}" --reverse --format='%aI' -- DESCRIPTION | head -1)
  [ -z "$since" ] && since=$(date -u -d '60 days ago' +%Y-%m-%dT%H:%M:%SZ)
fi
echo "sampling oppdateringer since ${since}" >&2
python3 data-raw/api_monitor/schema_probe.py --out "$out" --since "$since"
Rscript data-raw/api_monitor/run.R "$out" "$@"
