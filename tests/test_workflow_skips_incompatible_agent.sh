#!/usr/bin/env bash
# Valida que todo workflow activo declare un bloque # Gates evaluado antes de activar agentes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/workflows/*.md; do
  base=$(basename "$f")
  [ "$base" = "_WORKFLOW_CONTRACT_TEMPLATE.md" ] && continue
  if grep -q '^# Gates' "$f" && grep -A10 '^# Gates' "$f" | grep -q 'gates:'; then
    echo "[PASS] $f declara bloque # Gates"
  else
    echo "[FAIL] $f no declara bloque # Gates"
    FAIL=1
  fi
done

if grep -q 'CAPABILITY FILTER' "$ROOT/docs/CONTRACTS.md" && grep -q 'AGENT FILTER' "$ROOT/docs/CONTRACTS.md"; then
  echo "[PASS] docs/CONTRACTS.md define el pipeline DISCOVERY -> CAPABILITY FILTER -> AGENT FILTER"
else
  echo "[FAIL] docs/CONTRACTS.md no define el pipeline de filtrado antes de activar agentes"
  FAIL=1
fi

exit $FAIL
