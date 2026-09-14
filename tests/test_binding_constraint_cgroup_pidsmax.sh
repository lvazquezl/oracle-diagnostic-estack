#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 44/40.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FX="$ROOT/tests/fixtures/ol8-binding-constraint-cgroup.yaml"

[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'binding_constraint: CGROUP_PIDS_MAX' "$FX" && echo "[PASS] fixture declara binding_constraint CGROUP_PIDS_MAX" || { echo "[FAIL] falta el resultado esperado"; FAIL=1; }
exit $FAIL
