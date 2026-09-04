#!/usr/bin/env bash
# El Collector Contract declara supported_versions/GI home requirement por collector (# 20, # 11).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/GI_READONLY_COLLECTORS.md"

grep -q 'supported_versions: \[string\]' "$DOC" && echo "[PASS] Collector Contract declara supported_versions" || { echo "[FAIL] falta supported_versions en el schema"; FAIL=1; }
grep -q 'gi_home_requirement: bool' "$DOC" && echo "[PASS] Collector Contract declara gi_home_requirement" || { echo "[FAIL] falta gi_home_requirement"; FAIL=1; }
grep -q '10g legacy CRS/RAC' "$ROOT/agents/oracle-rac-analyst/manifest.yaml" && echo "[PASS] familias de versión GI/RAC declaradas en el manifest del agente" || { echo "[FAIL] falta la clasificación de familias de versión"; FAIL=1; }

exit $FAIL
