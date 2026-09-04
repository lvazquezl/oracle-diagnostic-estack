#!/usr/bin/env bash
# Valida que performance/pga declare NOT_APPLICABLE explícito para PGA_AGGREGATE_LIMIT en
# versiones < 12.1, nunca asumido presente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/performance/pga/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta performance/pga/SKILL.md"; exit 1; }
grep -q 'NOT_APPLICABLE' "$S" && echo "[PASS] declara NOT_APPLICABLE para versiones sin PGA_AGGREGATE_LIMIT" || { echo "[FAIL] no declara NOT_APPLICABLE"; FAIL=1; }
grep -qi 'nunca.*inventa\|nunca se asume' "$S" && echo "[PASS] declara que nunca se inventa/asume el valor" || { echo "[FAIL] falta la prohibición de inventar el valor"; FAIL=1; }

exit $FAIL
