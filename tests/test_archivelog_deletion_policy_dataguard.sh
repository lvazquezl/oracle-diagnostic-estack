#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45/28.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/dataguard-awareness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-dataguard-standby-backup.yaml"

grep -qi 'APPLIED ON STANDBY\|deletion policy.*standby' "$S" && echo "[PASS] rman/dataguard-awareness reconoce deletion policy consciente de standby" || { echo "[FAIL] falta el reconocimiento de la deletion policy"; FAIL=1; }
grep -qi 'APPLIED ON.*STANDBY' "$FX" && echo "[PASS] fixture declara ARCHIVELOG DELETION POLICY consciente de standby" || { echo "[FAIL] fixture no declara la policy"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] archivelog deletion policy Data Guard-aware certificada"
exit $FAIL
