#!/usr/bin/env bash
# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 76/15 (# 481-498 del prompt).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/capacity/oracle/SKILL.md"
FX="$ROOT/tests/fixtures/capacity-oracle-database-growth.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta fixture $FX"; exit 1; }
grep -q 'database_size_bytes: number|null' "$S" && echo "[PASS] declara database_size_bytes en el esquema" || { echo "[FAIL] falta database_size_bytes"; FAIL=1; }
grep -q 'Nunca consulta datos de negocio' "$S" && echo "[PASS] declara la prohibición de business data" || { echo "[FAIL] falta la prohibición de business data"; FAIL=1; }
grep -q 'INCREASING' "$FX" && echo "[PASS] fixture de crecimiento de base de datos presente" || { echo "[FAIL] fixture no declara INCREASING"; FAIL=1; }
exit $FAIL
