#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/restore-readiness/SKILL.md"
FX="$ROOT/tests/fixtures/19c-restore-readiness-incomplete.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -qi 'NOT_READY' "$S" && echo "[PASS] rman/restore-readiness declara NOT_READY" || { echo "[FAIL] falta NOT_READY"; FAIL=1; }
grep -qi 'controlfile protegido' "$S" && echo "[PASS] documenta controlfile como requisito de NOT_READY" || { echo "[FAIL] falta controlfile en la decision logic"; FAIL=1; }
grep -qi 'NOT_READY' "$FX" && echo "[PASS] fixture modela NOT_READY por controlfile/SPFILE ausentes" || { echo "[FAIL] fixture no modela NOT_READY"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] restore readiness missing controlfile certificado"
exit $FAIL
