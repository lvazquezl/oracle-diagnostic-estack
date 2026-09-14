#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 43/22.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'type: KERNEL_PID_MAX' "$S" && grep -q 'scope: HOST' "$S" && echo "[PASS] declara KERNEL_PID_MAX con scope HOST" || { echo "[FAIL] falta KERNEL_PID_MAX/scope HOST"; FAIL=1; }
exit $FAIL
