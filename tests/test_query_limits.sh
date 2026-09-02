#!/usr/bin/env bash
# Valida que toda query certificada declare timeout y max_rows.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/queries/Q-*.md; do
  [ -f "$f" ] || continue
  if grep -q '^timeout_seconds:' "$f" && grep -q '^max_rows:' "$f"; then
    echo "[PASS] $f declara timeout_seconds y max_rows"
  else
    echo "[FAIL] $f no declara timeout_seconds/max_rows"
    FAIL=1
  fi
done

# La tabla de costo/riesgo del registro debe tener columnas risk_class/cost_class/timeout_s/max_rows pobladas
if grep -q 'risk_class | cost_class | timeout_s | max_rows' "$ROOT/queries/REGISTRY.md"; then
  echo "[PASS] queries/REGISTRY.md declara columnas risk_class/cost_class/timeout_s/max_rows"
else
  echo "[FAIL] queries/REGISTRY.md no declara columnas risk_class/cost_class/timeout_s/max_rows"
  FAIL=1
fi

for f in "$ROOT"/queries/Q-*.md; do
  [ -f "$f" ] || continue
  if grep -q '^max_output_bytes:' "$f"; then
    echo "[PASS] $f declara max_output_bytes"
  else
    echo "[FAIL] $f no declara max_output_bytes (Query Contract v2)"
    FAIL=1
  fi
done

exit $FAIL
