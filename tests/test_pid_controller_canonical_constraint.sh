#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 36/19.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'process_constraint_pid_controller' "$S" && echo "[PASS] declara el modelo process_constraint_pid_controller" || { echo "[FAIL] falta process_constraint_pid_controller"; FAIL=1; }
if grep -q 'systemd_tasks_max:' "$S" && grep -q 'cgroup_pids_max:' "$S"; then
  echo "[PASS] declara ambas fuentes (systemd_tasks_max/cgroup_pids_max) en el constraint canónico"
else
  echo "[FAIL] faltan las fuentes del constraint canónico"; FAIL=1
fi
exit $FAIL
