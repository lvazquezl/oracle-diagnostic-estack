#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 46/22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
if grep -qi 'TasksMax' "$S" && grep -qi 'LimitNPROC' "$S" && grep -qi 'nunca tratados como sinónimos' "$S"; then
  echo "[PASS] declara TasksMax distinto de LimitNPROC, nunca sinónimos"
else
  echo "[FAIL] falta la distinción TasksMax/LimitNPROC"; FAIL=1
fi
exit $FAIL
