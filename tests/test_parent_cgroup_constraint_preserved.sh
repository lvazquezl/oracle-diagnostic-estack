#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 37/32.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/skills/os/cgroups/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-parent-cgroup-constraint.yaml"

[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'PARENT' "$C" && echo "[PASS] os/cgroups declara la relación PARENT" || { echo "[FAIL] falta PARENT en os/cgroups"; FAIL=1; }
grep -q 'constraints_count: 2' "$FX" && grep -q 'deduplicated: false' "$FX" \
  && echo "[PASS] fixture preserva parent y unit como constraints separados" || { echo "[FAIL] falta el resultado esperado"; FAIL=1; }
exit $FAIL
