#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/ephemeral-ports/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'range_size = max - min' "$S" && echo "[PASS] declara el cálculo de range_size" || { echo "[FAIL] falta range_size"; FAIL=1; }
grep -q 'ORA-27530' "$S" && echo "[PASS] correlaciona con ORA-27530" || { echo "[FAIL] falta ORA-27530"; FAIL=1; }
grep -qi 'nunca atribuir el error' "$S" && echo "[PASS] prohíbe atribuir el error sin evidencia" || { echo "[FAIL] falta la prohibición de atribución automática"; FAIL=1; }
exit $FAIL
