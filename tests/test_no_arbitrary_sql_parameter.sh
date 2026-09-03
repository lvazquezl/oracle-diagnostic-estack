#!/usr/bin/env bash
# Valida que ninguna tool del manifest MCP ni query Oracle Core acepte un parámetro sql/command/
# script/shell/query de texto libre.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='\bsql:\s*string\b|\bcommand:\s*string\b|\bscript:\s*string\b|\bshell:\s*string\b|\braw_query\b'

HITS=$(grep -E "$PATTERN" "$ROOT/mcp/tool-manifest.md" | grep -viE 'ninguna tool acepta|nunca acepta|no acepta' || true)
if [ -n "$HITS" ]; then
  echo "[FAIL] mcp/tool-manifest.md declara un parámetro de texto libre"
  FAIL=1
else
  echo "[PASS] mcp/tool-manifest.md no declara ningún parámetro de texto libre sql/command/script/shell"
fi

exit $FAIL
