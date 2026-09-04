#!/usr/bin/env bash
# Valida que ninguna query de queries/performance/ acepte SQL/parámetro de texto libre (ningún
# placeholder tipo :sql/:command/:raw_query) y que toda MCP tool de performance en
# mcp/tool-manifest.md mapee a query_id certificados, nunca a un parámetro libre.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/performance" -name 'Q-*.md'); do
  if grep -Eq ':sql\b|:command\b|:raw_query\b' "$f"; then
    echo "[FAIL] $f acepta un parámetro de SQL/comando de texto libre"
    FAIL=1
  fi
done

if grep -qE '"sql"|"command"|"raw_query"' "$ROOT/mcp/tool-manifest.md"; then
  echo "[FAIL] mcp/tool-manifest.md declara un parámetro sql/command/raw_query"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] Ninguna query/tool de performance acepta SQL arbitrario"

exit $FAIL
