#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 15-18.
# "latest: SUPPORTED" fue ELIMINADO por completo de la fila dataguard (no sólo reinterpretado por
# comentario, como en el hardening anterior) — reemplazado por future_status:
# COMPATIBILITY_VALIDATION_REQUIRED, coherente con la declaración UNKNOWN_FUTURE del agente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
CAP="$ROOT/config/capability-matrix.yaml"
DOC="$ROOT/docs/CAPABILITY_MATRIX.md"
MANIFEST="$ROOT/agents/oracle-dataguard-analyst/manifest.yaml"

dg_row=$(awk '/id: dataguard/{flag=1} flag{print} flag && /^  - id:/ && !/id: dataguard/{exit}' "$CAP")

if echo "$dg_row" | grep -qE 'versions: \{[^}]*latest:'; then
  echo "[FAIL] la fila dataguard todavía declara 'latest:' dentro de versions: {...}"
  FAIL=1
else
  echo "[PASS] la fila dataguard ya no declara 'latest:' dentro de versions: {...} — eliminado, no reinterpretado"
fi

echo "$dg_row" | grep -q 'future_status: COMPATIBILITY_VALIDATION_REQUIRED' && echo "[PASS] la fila dataguard declara future_status: COMPATIBILITY_VALIDATION_REQUIRED explícitamente" || { echo "[FAIL] falta future_status: COMPATIBILITY_VALIDATION_REQUIRED en la fila dataguard"; FAIL=1; }
echo "$dg_row" | grep -qi 'UNKNOWN_FUTURE' && echo "[PASS] config/capability-matrix.yaml (fila dataguard) referencia UNKNOWN_FUTURE explícitamente, sin contradicción con el agente" || { echo "[FAIL] la fila dataguard de capability-matrix.yaml no reconcilia con UNKNOWN_FUTURE"; FAIL=1; }

grep -qi 'COMPATIBILITY_VALIDATION_REQUIRED' "$DOC" && echo "[PASS] docs/CAPABILITY_MATRIX.md documenta COMPATIBILITY_VALIDATION_REQUIRED para Data Guard" || { echo "[FAIL] falta COMPATIBILITY_VALIDATION_REQUIRED en docs/CAPABILITY_MATRIX.md"; FAIL=1; }

grep -q 'status: UNKNOWN_FUTURE' "$MANIFEST" && echo "[PASS] agents/oracle-dataguard-analyst/manifest.yaml sigue siendo la fuente de verdad de UNKNOWN_FUTURE" || { echo "[FAIL] el manifest ya no declara UNKNOWN_FUTURE"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] 'latest: SUPPORTED' fue eliminado en Data Guard — versiones futuras desconocidas nunca heredan soporte automático"

exit $FAIL
