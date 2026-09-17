#!/usr/bin/env bash
# Ninguna query Data Guard acepta SQL de texto libre — todas usan bloques SQL fijos certificados,
# sin interpolación de parámetros no validados salvo :time_window_hours ya acotado (# 55).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f")
  # Cualquier bind variable debe ser uno de los parámetros ya acotados y documentados.
  binds=$(echo "$block" | grep -oE ':[a-z_]+' | sort -u)
  for b in $binds; do
    if [ "$b" != ":time_window_hours" ]; then
      echo "[FAIL] $f usa bind variable no documentado: $b"
      FAIL=1
    fi
  done
done

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query Data Guard acepta SQL/parámetros no acotados"

# PHASE 10 — CAPACITY MANAGEMENT & FORECASTING, sección 81 (# 58 del prompt: NO ARBITRARY SQL).
M="$ROOT/agents/capacity-analyst/manifest.yaml"
[ -f "$M" ] || { echo "[FAIL] falta $M"; FAIL=1; }
if [ -f "$M" ]; then
  grep -q 'SQL arbitrario' "$M" && echo "[PASS] capacity-analyst declara la prohibición de SQL arbitrario" || { echo "[FAIL] falta la prohibición de SQL arbitrario en capacity-analyst"; FAIL=1; }
fi

exit $FAIL
