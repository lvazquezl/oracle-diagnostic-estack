#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 44/41.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-binding-constraint-unknown-usage.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'menor valor configurado como sustituto' "$S" \
  && echo "[PASS] prohíbe elegir el constraint con menor valor configurado como sustituto" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
grep -q 'binding_constraint: UNKNOWN' "$FX" && echo "[PASS] fixture declara binding_constraint UNKNOWN" || { echo "[FAIL] falta el resultado esperado"; FAIL=1; }
grep -q 'binding_constraint_chosen_by_min_configured: false' "$FX" && echo "[PASS] fixture confirma que no se eligió por mínimo configurado" || { echo "[FAIL] falta la confirmación"; FAIL=1; }
exit $FAIL
