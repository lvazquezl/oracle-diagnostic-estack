#!/usr/bin/env bash
# Ningún artefacto declara ENABLE/DISABLE CONFIGURATION ejecutable (# 24).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/dataguard/*.py "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>15?lineno-15:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead'; then
      echo "[FAIL] $f:$lineno contiene ENABLE/DISABLE CONFIGURATION sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '(ENABLE|DISABLE) CONFIGURATION' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara ENABLE/DISABLE CONFIGURATION ejecutable"
exit $FAIL
