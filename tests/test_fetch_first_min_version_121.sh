#!/usr/bin/env bash
# PHASE 7 — RMAN LEGACY SQL SYNTAX & QUERY CERTIFICATION HARDENING, sección 44/13.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
FEATURES="$ROOT/compatibility/oracle-sql-syntax/features.yaml"

block=$(awk '/^  FETCH_FIRST:/{f=1;print;next} f && /^  [A-Za-z_]+:[ \t]*$/{exit} f{print}' "$FEATURES")
echo "$block" | grep -q 'min_version: "12.1"' && echo "[PASS] FETCH_FIRST declara min_version 12.1" || { echo "[FAIL] FETCH_FIRST no declara min_version 12.1"; FAIL=1; }
echo "$block" | grep -qi 'FETCH.*FIRST' && echo "[PASS] FETCH_FIRST declara syntax_patterns para FETCH FIRST" || { echo "[FAIL] falta el patrón FETCH FIRST"; FAIL=1; }
echo "$block" | grep -q 'source_type: ORACLE_DOCUMENTATION' && echo "[PASS] FETCH_FIRST declara validation.source_type" || { echo "[FAIL] falta validation.source_type"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] FETCH_FIRST min_version 12.1 certificado"
exit $FAIL
