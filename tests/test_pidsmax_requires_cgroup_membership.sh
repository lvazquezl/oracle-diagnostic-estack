#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 45/31.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
C="$ROOT/skills/os/cgroups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
if grep -qi 'membership en ese cgroup' "$S"; then
  echo "[PASS] os/process-limits requiere confirmar membership del PID en el cgroup"
else
  echo "[FAIL] falta el requisito de membership de cgroup en os/process-limits"; FAIL=1
fi
grep -q 'membership_confirmed' "$C" && echo "[PASS] os/cgroups declara membership_confirmed en el output" || { echo "[FAIL] falta membership_confirmed en os/cgroups"; FAIL=1; }
exit $FAIL
