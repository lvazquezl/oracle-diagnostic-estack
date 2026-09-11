#!/usr/bin/env bash
# PHASE 7 — ORACLE BACKUP & RECOVERY / RMAN, sección 44.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rman/fra-pressure/SKILL.md"
FX="$ROOT/tests/fixtures/19c-fra-pressure.yaml"

[ -f "$FX" ] || { echo "[FAIL] $FX no existe"; exit 1; }
grep -qi 'CRITICAL' "$S" && echo "[PASS] rman/fra-pressure declara severidad CRITICAL" || { echo "[FAIL] falta CRITICAL"; FAIL=1; }
grep -qi 'CRITICAL' "$FX" && echo "[PASS] fixture modela un escenario CRITICAL" || { echo "[FAIL] fixture no modela CRITICAL"; FAIL=1; }
grep -qi 'riesgo de detener backups\|riesgo de detener' "$S" && echo "[PASS] documenta el riesgo real de FRA llena" || { echo "[FAIL] falta la explicación del riesgo"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] FRA critical classification certificada"
exit $FAIL
