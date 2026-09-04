#!/usr/bin/env bash
# Ningún collector/parser declara lsnrctl stop/start ejecutable.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq 'lsnrctl (stop|start)' "$f"; then
    echo "[FAIL] $f contiene 'lsnrctl stop/start' ejecutable"
    FAIL=1
  fi
done

grep -qi 'no reinicia el listener' "$ROOT/agents/oracle-network-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md prohíbe explícitamente reiniciar el listener" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara lsnrctl stop/start ejecutable"
exit $FAIL
