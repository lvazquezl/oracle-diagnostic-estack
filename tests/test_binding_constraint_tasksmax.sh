#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 44/39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/ol8-binding-constraint-tasksmax.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'binding_constraint: SYSTEMD_TASKS_MAX' "$FX" && echo "[PASS] fixture declara binding_constraint SYSTEMD_TASKS_MAX" || { echo "[FAIL] falta el resultado esperado"; FAIL=1; }
grep -qi 'nunca por el menor valor configurado' "$FX" && echo "[PASS] fixture documenta que no se elige por el menor valor configurado" || { echo "[FAIL] falta la aclaración"; FAIL=1; }
exit $FAIL
