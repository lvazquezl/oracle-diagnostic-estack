#!/usr/bin/env bash
# Valida que el pipeline de filtrado incluya explícitamente un SKILL FILTER (no sólo AGENT FILTER),
# y que exista la métrica skills_skipped_by_version/license.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
F="$ROOT/docs/CONTRACTS.md"

if grep -q 'SKILL FILTER' "$F"; then
  echo "[PASS] docs/CONTRACTS.md declara SKILL FILTER en el pipeline de activación"
else
  echo "[FAIL] docs/CONTRACTS.md no declara SKILL FILTER"
  FAIL=1
fi

for metric in agents_skipped_by_capability skills_skipped_by_version skills_skipped_by_license queries_skipped_by_cost; do
  if grep -q "$metric" "$F"; then
    echo "[PASS] métrica '$metric' declarada"
  else
    echo "[FAIL] falta métrica '$metric'"
    FAIL=1
  fi
done

exit $FAIL
