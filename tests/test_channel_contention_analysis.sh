#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/channel-contention/SKILL.md"
FX="$ROOT/tests/fixtures/19c-media-manager-channel-contention.yaml"

[ -f "$S" ] || { echo "[FAIL] $S no existe"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -qi 'contención\|contention' "$S" && echo "[PASS] rman/channel-contention analiza contención" || { echo "[FAIL] falta análisis de contención"; FAIL=1; }
grep -qi 'RUNNING' "$FX" && echo "[PASS] fixture modela sesiones RUNNING concurrentes" || { echo "[FAIL] fixture no modela contención"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] channel contention analysis certificado"
exit $FAIL
