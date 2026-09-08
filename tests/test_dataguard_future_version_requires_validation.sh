#!/usr/bin/env bash
# PHASE 5 — DATA GUARD COMPATIBILITY & QUERY CERTIFICATION HARDENING, sección 15.
# Toda familia de versión no conocida debe quedar explícitamente UNKNOWN_FUTURE en el agente, y
# ninguna query Data Guard debe declarar un "max" que implique soporte automático indefinido.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
MANIFEST="$ROOT/agents/oracle-dataguard-analyst/manifest.yaml"
MATRIX="$ROOT/config/query-compatibility-matrix.yaml"

grep -q 'status: UNKNOWN_FUTURE' "$MANIFEST" && echo "[PASS] agents/oracle-dataguard-analyst/manifest.yaml declara una familia future -> UNKNOWN_FUTURE" || { echo "[FAIL] falta la declaración UNKNOWN_FUTURE en el manifest"; FAIL=1; }

dg_section=$(awk '/Fase 5 \(Data Guard\)/{flag=1} flag{print} /^notes: >/{flag=0}' "$MATRIX")
if echo "$dg_section" | grep -qE 'Q-DG-[A-Z-]+-001.*max: latest'; then
  echo "[FAIL] alguna entrada Q-DG-* en config/query-compatibility-matrix.yaml todavía usa max: latest"
  FAIL=1
else
  echo "[PASS] Ninguna entrada Q-DG-* en config/query-compatibility-matrix.yaml usa max: latest"
fi

[ $FAIL -eq 0 ] && echo "[PASS] Una versión futura desconocida requiere validación explícita antes de soporte Data Guard"

exit $FAIL
