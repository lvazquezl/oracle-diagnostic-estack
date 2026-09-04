#!/usr/bin/env bash
# Ningún collector/parser declara crsctl {add|delete|replace} css votedisk.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='crsctl (add|delete|replace) css votedisk'

for f in "$ROOT"/parsers/rac/*.py "$ROOT/docs/GI_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  if grep -Eiq "$PATTERN" "$f"; then
    echo "[FAIL] $f contiene un comando de escritura de voting disk"
    FAIL=1
  fi
done

grep -qi 'no agrega/quita/reemplaza voting disks' "$ROOT/skills/rac/gi-voting-status/SKILL.md" \
  && echo "[PASS] rac/gi-voting-status prohíbe explícitamente cambios de voting disk" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara escritura de voting disk"
exit $FAIL
