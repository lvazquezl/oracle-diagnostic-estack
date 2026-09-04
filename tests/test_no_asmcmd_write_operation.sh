#!/usr/bin/env bash
# Ningún collector/parser declara una operación de escritura de asmcmd (mkdg, rm, chdg, offline/online).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='asmcmd (mkdg|rm |chdg|offline|online|mkalias|rmalias|dropdg|remap)'

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene una operación de escritura de asmcmd"
    FAIL=1
  fi
done

grep -qi 'asmcmd write operations' "$ROOT/agents/oracle-asm-storage-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente asmcmd write operations" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara operación de escritura de asmcmd"
exit $FAIL
