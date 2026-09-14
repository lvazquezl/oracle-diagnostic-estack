#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 38/31.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-tasksmax-pidsmax-configuration-mismatch.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'difiere del estado runtime' "$S" && echo "[PASS] declara la detección de mismatch TasksMax/pids.max" || { echo "[FAIL] falta la detección de mismatch"; FAIL=1; }
grep -q 'configuration_effective_mismatch: true' "$FX" && echo "[PASS] fixture declara configuration_effective_mismatch: true" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
grep -q 'restart_recommended_automatically: false' "$FX" && echo "[PASS] fixture confirma que no se recomienda restart automático" || { echo "[FAIL] falta la confirmación de no-restart"; FAIL=1; }
exit $FAIL
