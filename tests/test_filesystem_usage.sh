#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/filesystems/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'oracle_role' "$S" && echo "[PASS] declara oracle_role por mount" || { echo "[FAIL] falta oracle_role"; FAIL=1; }
grep -qi 'severidad depende del.\?rol' "$S" && echo "[PASS] declara que la severidad depende del rol, no genérico" || { echo "[FAIL] falta la regla de severidad por rol"; FAIL=1; }
exit $FAIL
