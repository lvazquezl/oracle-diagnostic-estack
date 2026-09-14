#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/transparent-hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'regla universal sin fuente' "$S" && echo "[PASS] prohíbe recomendación universal sin fuente" || { echo "[FAIL] falta la prohibición de regla universal"; FAIL=1; }
grep -q 'recommendation_source' "$S" && echo "[PASS] declara recommendation_source en el output" || { echo "[FAIL] falta recommendation_source"; FAIL=1; }
exit $FAIL
