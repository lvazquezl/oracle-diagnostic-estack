#!/usr/bin/env bash
# Ningún artefacto ejecuta REINSTATE DATABASE.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/dataguard/*.py "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>15?lineno-15:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead'; then
      echo "[FAIL] $f:$lineno contiene REINSTATE DATABASE sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE 'REINSTATE DATABASE' "$f")
done

grep -q 'REINSTATE DATABASE' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente reinstate" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto ejecuta REINSTATE DATABASE"
exit $FAIL
