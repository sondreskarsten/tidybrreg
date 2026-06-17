#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
out="${TMPDIR:-/tmp}/tidybrreg_schema_current.tsv"
prev_ver=$(grep -E '^# tidybrreg' NEWS.md | sed -n 2p | awk '{print $3}')
since=$(git log -S"Version: ${prev_ver}" --reverse --format='%aI' -- DESCRIPTION | head -1)
[ -z "$since" ] && since=$(date -u -d '60 days ago' +%Y-%m-%dT%H:%M:%SZ)
echo "sampling oppdateringer since ${prev_ver} release: ${since}" >&2
python3 data-raw/api_monitor/schema_probe.py --out "$out" --since "$since"
Rscript data-raw/api_monitor/run.R "$out" "$@"
