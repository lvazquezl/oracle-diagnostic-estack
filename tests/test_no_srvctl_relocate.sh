#!/usr/bin/env bash
# Ningún collector/parser/query declara srvctl relocate ejecutable.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq 'srvctl relocate' "$f"; then
    echo "[FAIL] $f contiene 'srvctl relocate' ejecutable"
    FAIL=1
  fi
done

grep -qi 'no relocaliza servicios ni instancias' "$ROOT/skills/rac/failover/SKILL.md" \
  && echo "[PASS] rac/failover prohíbe explícitamente relocate" \
  || { echo "[FAIL] falta prohibición explícita de relocate en rac/failover"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara srvctl relocate ejecutable"
exit $FAIL
