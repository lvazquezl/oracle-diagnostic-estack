#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 45.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"
FX="$ROOT/tests/fixtures/19c-sbt-backup.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -q 'library_detected: true' "$S" && echo "[PASS] rman/sbt-media-manager declara library_detected: true en la decision logic" || { echo "[FAIL] falta library_detected: true"; FAIL=1; }
grep -qi 'SBT_TAPE' "$FX" && echo "[PASS] fixture modela DEFAULT DEVICE TYPE SBT_TAPE" || { echo "[FAIL] fixture no modela SBT_TAPE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] SBT device detection certificada"
exit $FAIL
