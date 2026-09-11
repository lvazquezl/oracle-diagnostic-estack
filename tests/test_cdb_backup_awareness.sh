#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/29.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/multitenant-awareness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-pdb-backup-context.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -q 'CON_ID = 1' "$S" && echo "[PASS] rman/multitenant-awareness distingue CON_ID=1 (whole CDB)" || { echo "[FAIL] falta la distinción CON_ID=1"; FAIL=1; }
grep -q 'con_id: 1' "$FX" && echo "[PASS] fixture modela backup CON_ID=1" || { echo "[FAIL] fixture no modela CON_ID=1"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] CDB backup awareness certificado"
exit $FAIL
