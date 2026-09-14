#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-parent-cgroup-constraint.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'unit/parent/child/delegado' "$S" && echo "[PASS] declara que binding_constraint puede provenir de un nodo parent" || { echo "[FAIL] falta la referencia a parent en binding_constraint"; FAIL=1; }
grep -q 'binding_constraint_candidate: "CGROUP_PATH_TOKEN_SYSTEM_SLICE"' "$FX" \
  && echo "[PASS] fixture declara el parent como candidato a binding constraint" || { echo "[FAIL] falta el candidato parent en la fixture"; FAIL=1; }
exit $FAIL
