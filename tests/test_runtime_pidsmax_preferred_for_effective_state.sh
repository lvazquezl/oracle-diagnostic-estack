#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 38/20.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-tasksmax-pidsmax-configuration-mismatch.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
if grep -qi 'prevalece para describir la restricción' "$S"; then
  echo "[PASS] declara que el estado runtime prevalece para la restricción efectiva"
else
  echo "[FAIL] falta la regla de precedencia runtime"; FAIL=1
fi
grep -q 'effective_runtime_constraint: 1024' "$FX" && echo "[PASS] fixture confirma que el runtime (1024) es el efectivo, no el configurado (2048)" || { echo "[FAIL] falta la confirmación en la fixture"; FAIL=1; }
exit $FAIL
