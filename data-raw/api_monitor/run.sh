#!/usr/bin/env bash
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
out="${TMPDIR:-/tmp}/tidybrreg_schema_current.tsv"
python3 data-raw/api_monitor/schema_probe.py --out "$out"
Rscript data-raw/api_monitor/run.R "$out" "$@"
