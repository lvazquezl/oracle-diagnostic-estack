#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 36/86.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
if grep -qi 'en vez de' "$S" && grep -q 'entradas separadas' "$S"; then
  echo "[PASS] declara que el canonical PID_CONTROLLER reemplaza las dos entradas separadas"
else
  echo "[FAIL] falta la regla de reemplazo"; FAIL=1
fi
exit $FAIL
