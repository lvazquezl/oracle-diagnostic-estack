#!/usr/bin/env bash
# Valida que context-policy.yaml materialice los presupuestos/reglas de contexto
# (# 29 CONTEXT POLICY).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
C="$ROOT/agents/oracle-performance-analyst/context-policy.yaml"

[ -f "$C" ] || { echo "[FAIL] falta context-policy.yaml"; exit 1; }

for field in "^minimum_context:" "^evidence_by_reference:" "^top_n:" "^no_full_report:" "^no_full_history:" "^no_sql_text_default:" "^no_bind_values:" "^context_budget:"; do
  if grep -q "$field" "$C"; then
    echo "[PASS] context-policy.yaml declara $field"
  else
    echo "[FAIL] context-policy.yaml no declara $field"
    FAIL=1
  fi
done

grep -q 'top_sql_default: 10' "$C" && echo "[PASS] top_sql_default configurado" || { echo "[FAIL] falta top_sql_default"; FAIL=1; }

exit $FAIL
