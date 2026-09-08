#!/usr/bin/env bash
# PHASE 5 — DATA GUARD FINAL PROCESS-VIEW & PORTABILITY HARDENING, sección 18.
# La fila dataguard de config/capability-matrix.yaml y docs/CAPABILITY_MATRIX.md ya no deben
# declarar "latest: SUPPORTED" — eliminado estructuralmente, no reinterpretado por comentario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
CAP="$ROOT/config/capability-matrix.yaml"
DOC="$ROOT/docs/CAPABILITY_MATRIX.md"

# Alcance estricto a la línea versions: {...} (estructura), no a las notas en prosa que puedan
# mencionar la frase al explicar que fue eliminada.
dg_versions_line=$(awk '/id: dataguard/{flag=1} flag && /^    versions:/{print; exit}' "$CAP")
if echo "$dg_versions_line" | grep -qE '\blatest:'; then
  echo "[FAIL] config/capability-matrix.yaml (fila dataguard) — versions: {...} todavía declara la clave 'latest:'"
  FAIL=1
else
  echo "[PASS] config/capability-matrix.yaml (fila dataguard) — versions: {...} no declara la clave 'latest:'"
fi

dg_table_row=$(grep '^| Data Guard ' "$DOC")
if echo "$dg_table_row" | grep -qE '\| SUPPORTED \|$'; then
  echo "[FAIL] docs/CAPABILITY_MATRIX.md — la última columna (latest) de la fila Data Guard sigue siendo SUPPORTED"
  FAIL=1
else
  echo "[PASS] docs/CAPABILITY_MATRIX.md — la última columna (latest) de la fila Data Guard ya no es SUPPORTED"
fi

[ $FAIL -eq 0 ] && echo "[PASS] No queda ningún 'latest: SUPPORTED' para Data Guard en config/capability-matrix.yaml ni docs/CAPABILITY_MATRIX.md"

exit $FAIL
