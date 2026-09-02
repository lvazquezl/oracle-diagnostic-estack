#!/usr/bin/env bash
# Valida que ninguna tool MCP declare shell o SQL arbitrario.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

if grep -Eq 'execute_any_shell_command|execute_shell\(|execute_sql\(\s*sql' "$ROOT/mcp/tool-manifest.md"; then
  echo "[FAIL] mcp/tool-manifest.md declara una tool de shell/SQL arbitrario"
  FAIL=1
else
  echo "[PASS] mcp/tool-manifest.md no declara shell/SQL arbitrario"
fi

# Sólo se audita el manifest de tools real (fuente de verdad de parámetros), no la prosa
# de README/políticas que legítimamente describe estos patrones como PROHIBIDOS.
if grep -Eq '\bsql:\s*string\b|\bcommand:\s*string\b|\braw_query\s*:' "$ROOT/mcp/tool-manifest.md"; then
  echo "[FAIL] mcp/tool-manifest.md declara un parámetro de texto libre (sql/command/raw_query)"
  FAIL=1
else
  echo "[PASS] Ninguna tool en mcp/tool-manifest.md acepta parámetro de texto libre sql/command/raw_query"
fi

exit $FAIL
