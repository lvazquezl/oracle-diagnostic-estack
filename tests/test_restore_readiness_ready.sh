#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/restore-readiness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-restore-readiness-healthy.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -q 'READY|READY_WITH_WARNINGS|NOT_READY|INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] rman/restore-readiness declara el enum completo" || { echo "[FAIL] falta el enum de restore readiness"; FAIL=1; }
grep -qi 'status: READY' "$FX" && echo "[PASS] fixture modela READY con evidencia completa" || { echo "[FAIL] fixture no modela READY"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] restore readiness READY certificado"
exit $FAIL
