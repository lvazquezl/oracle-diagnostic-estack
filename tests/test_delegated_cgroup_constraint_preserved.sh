#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 37/22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/skills/os/cgroups/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-child-delegated-cgroup-constraint.yaml"

[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'DELEGATED' "$C" && echo "[PASS] os/cgroups declara la relación DELEGATED" || { echo "[FAIL] falta DELEGATED en os/cgroups"; FAIL=1; }
grep -q 'relation: DELEGATED' "$FX" && echo "[PASS] fixture usa relation DELEGATED" || { echo "[FAIL] falta relation DELEGATED en la fixture"; FAIL=1; }
exit $FAIL
