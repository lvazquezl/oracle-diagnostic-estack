#!/usr/bin/env bash
# Ningún collector/parser declara un source_command de crsctl con verbo de cambio.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='crsctl (start|stop|modify|add|delete|relocate|replace|unpin|pin|setperm)'

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un verbo de cambio de crsctl"
    FAIL=1
  fi
done

grep -qi 'no modifica recursos Clusterware/OCR/voting' "$ROOT/agents/oracle-rac-analyst/AGENT.md" \
  && echo "[PASS] AGENT.md prohíbe explícitamente modificación de recursos/OCR/voting" \
  || { echo "[FAIL] falta prohibición explícita en AGENT.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún collector/parser declara crsctl de escritura"
exit $FAIL
