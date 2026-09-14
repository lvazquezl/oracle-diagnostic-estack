#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 43/23.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"
C="$ROOT/skills/os/cgroups/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$C" ] || { echo "[FAIL] falta $C"; exit 1; }
grep -qi 'Prohibido.\?.\? cualquier lógica equivalente a .min(RLIMIT_NPROC' "$S" \
  && echo "[PASS] prohíbe min(RLIMIT_NPROC, TasksMax, pids.max, pid_max)" || { echo "[FAIL] falta la prohibición de min()"; FAIL=1; }
BODY=$(sed '/^# Change history$/,$d' "$C")
if echo "$BODY" | grep -qi 'el más restrictivo entre cgroup'; then
  echo "[FAIL] os/cgroups todavía declara la regla incorrecta de mínimo universal como regla vigente"
  FAIL=1
else
  echo "[PASS] os/cgroups ya no declara la regla incorrecta de mínimo universal como regla vigente (sólo puede quedar citada en Change history como defecto corregido)"
fi
exit $FAIL
