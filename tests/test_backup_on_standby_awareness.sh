#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/28.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/dataguard-awareness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-dataguard-standby-backup.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -q 'backup_on_standby' "$S" && echo "[PASS] rman/dataguard-awareness declara backup_on_standby" || { echo "[FAIL] falta backup_on_standby"; FAIL=1; }
grep -qi 'physical_standby' "$FX" && echo "[PASS] fixture modela rol physical_standby" || { echo "[FAIL] fixture no modela standby"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] backup on standby awareness certificado"
exit $FAIL
