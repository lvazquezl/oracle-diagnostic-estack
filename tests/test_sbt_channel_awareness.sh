#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/sbt-media-manager/SKILL.md"

grep -qi 'SBT_TAPE' "$S" && echo "[PASS] rman/sbt-media-manager reconoce SBT_TAPE" || { echo "[FAIL] falta reconocimiento de SBT_TAPE"; FAIL=1; }
grep -qi 'library_detected' "$S" && echo "[PASS] declara library_detected en el output schema" || { echo "[FAIL] falta library_detected"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] SBT channel awareness certificado"
exit $FAIL
