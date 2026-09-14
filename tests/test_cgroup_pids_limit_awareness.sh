#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 46/23.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
C="$ROOT/skills/os/cgroups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
grep -qi 'CGROUP_PIDS_MAX' "$S" && echo "[PASS] os/process-limits declara el constraint CGROUP_PIDS_MAX" || { echo "[FAIL] falta CGROUP_PIDS_MAX en os/process-limits"; FAIL=1; }
grep -q 'pids_constraint' "$C" && echo "[PASS] os/cgroups declara pids_constraint en el output" || { echo "[FAIL] falta pids_constraint en os/cgroups"; FAIL=1; }
exit $FAIL
