#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 39.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'pid_controller:' "$S" && echo "[PASS] declara el bloque pid_controller en el output" || { echo "[FAIL] falta el bloque pid_controller"; FAIL=1; }
grep -q 'deduplicated: bool' "$S" && echo "[PASS] declara deduplicated en el output" || { echo "[FAIL] falta deduplicated"; FAIL=1; }
exit $FAIL
