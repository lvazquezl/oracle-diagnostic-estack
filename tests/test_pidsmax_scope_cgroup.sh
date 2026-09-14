#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 43/21.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
C="$ROOT/skills/os/cgroups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
grep -q 'type: CGROUP_PIDS_MAX' "$S" && grep -q 'scope: CGROUP' "$S" && echo "[PASS] declara CGROUP_PIDS_MAX con scope CGROUP" || { echo "[FAIL] falta CGROUP_PIDS_MAX/scope CGROUP"; FAIL=1; }
grep -q 'CGROUP_PIDS_MAX' "$C" && echo "[PASS] os/cgroups declara el tipo CGROUP_PIDS_MAX" || { echo "[FAIL] falta CGROUP_PIDS_MAX en os/cgroups"; FAIL=1; }
exit $FAIL
