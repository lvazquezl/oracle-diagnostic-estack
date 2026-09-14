#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 68.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/hugepages/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'shortfall > 0.*HIGH\|shortfall > 0.*`HIGH`' "$S" && echo "[PASS] declara HIGH cuando shortfall > 0" || { echo "[FAIL] falta la regla HIGH"; FAIL=1; }
grep -qi 'ORA-27102' "$S" && echo "[PASS] documenta el riesgo real ORA-27102" || { echo "[FAIL] falta la referencia a ORA-27102"; FAIL=1; }
exit $FAIL
