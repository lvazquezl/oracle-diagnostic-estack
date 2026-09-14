#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/grid-processes/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'RAC/RAC One Node exclusivamente' "$S" && echo "[PASS] declara alcance exclusivo RAC/RAC One Node" || { echo "[FAIL] falta el alcance RAC exclusivo"; FAIL=1; }
grep -qi 'nunca reemplaza a' "$S" && grep -q 'oracle-rac-analyst' "$S" \
  && echo "[PASS] declara que nunca reemplaza a oracle-rac-analyst" || { echo "[FAIL] falta la regla de no-reemplazo"; FAIL=1; }
exit $FAIL
