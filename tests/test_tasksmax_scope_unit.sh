#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 43/20.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'type: SYSTEMD_TASKS_MAX' "$S" && grep -q 'scope: UNIT' "$S" && echo "[PASS] declara SYSTEMD_TASKS_MAX con scope UNIT" || { echo "[FAIL] falta SYSTEMD_TASKS_MAX/scope UNIT"; FAIL=1; }
exit $FAIL
