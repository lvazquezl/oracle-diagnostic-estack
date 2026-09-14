#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 36/30.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-tasksmax-pidsmax-same-node.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q '# PID controller canonical model' "$S" && echo "[PASS] declara la sección PID controller canonical model" || { echo "[FAIL] falta la sección"; FAIL=1; }
grep -q 'canonical_type: PID_CONTROLLER' "$FX" && grep -q 'deduplicated: true' "$FX" \
  && echo "[PASS] fixture declara deduplicación en PID_CONTROLLER" || { echo "[FAIL] falta el resultado esperado"; FAIL=1; }
exit $FAIL
