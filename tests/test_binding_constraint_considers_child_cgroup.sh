#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-child-delegated-cgroup-constraint.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'child/delegado' "$S" && echo "[PASS] declara que binding_constraint puede provenir de un nodo child/delegated" || { echo "[FAIL] falta la referencia a child/delegated en binding_constraint"; FAIL=1; }
grep -q 'delegated_pids_max: 512' "$FX" && echo "[PASS] fixture declara el pids_max del cgroup delegado" || { echo "[FAIL] falta delegated_pids_max en la fixture"; FAIL=1; }
exit $FAIL
