#!/usr/bin/env bash
# Ningún collector/parser declara lsnrctl reload/set ejecutable.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq 'lsnrctl (reload|set )' "$f"; then
    echo "[FAIL] $f contiene 'lsnrctl reload/set' ejecutable"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara lsnrctl reload/set ejecutable"
exit $FAIL
