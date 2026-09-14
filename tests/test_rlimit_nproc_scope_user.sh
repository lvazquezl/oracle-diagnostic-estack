#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 43/19.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'type: RLIMIT_NPROC' "$S" && grep -q 'scope: USER' "$S" && echo "[PASS] declara RLIMIT_NPROC con scope USER" || { echo "[FAIL] falta RLIMIT_NPROC/scope USER"; FAIL=1; }
exit $FAIL
