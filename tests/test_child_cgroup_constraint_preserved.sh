#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 37/33.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/skills/os/cgroups/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-child-delegated-cgroup-constraint.yaml"

[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'CHILD' "$C" && echo "[PASS] os/cgroups declara la relación CHILD" || { echo "[FAIL] falta CHILD en os/cgroups"; FAIL=1; }
grep -q 'child_constraint_preserved: true' "$FX" && echo "[PASS] fixture confirma que el constraint hijo se preserva" || { echo "[FAIL] falta la confirmación en la fixture"; FAIL=1; }
exit $FAIL
