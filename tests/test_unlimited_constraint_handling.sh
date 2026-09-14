#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 44/30.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'se normalizan como .UNLIMITED.' "$S" && echo "[PASS] normaliza unlimited/infinity/max como UNLIMITED" || { echo "[FAIL] falta la normalización UNLIMITED"; FAIL=1; }
grep -q 'UNLIMITED.\?/.\?FINITE.\?/.\?UNKNOWN' "$S" && echo "[PASS] declara los 3 estados UNLIMITED/FINITE/UNKNOWN" || { echo "[FAIL] faltan los 3 estados"; FAIL=1; }
exit $FAIL
