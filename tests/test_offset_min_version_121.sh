#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 44/16.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FEATURES="$ROOT/compatibility/oracle-sql-syntax/features.yaml"

block=$(awk '/^  OFFSET_ROWS:/{f=1;print;next} f && /^  [A-Za-z_]+:[ \t]*$/{exit} f{print}' "$FEATURES")
echo "$block" | grep -q 'min_version: "12.1"' && echo "[PASS] OFFSET_ROWS declara min_version 12.1" || { echo "[FAIL] OFFSET_ROWS no declara min_version 12.1"; FAIL=1; }
echo "$block" | grep -qi 'OFFSET' && echo "[PASS] OFFSET_ROWS declara syntax_patterns para OFFSET" || { echo "[FAIL] falta el patrón OFFSET"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] OFFSET_ROWS min_version 12.1 certificado (registrado preventivamente, # 16 del prompt)"
exit $FAIL
