#!/usr/bin/env bash
# Ningún artefacto declara execute_dgmgrl(command) genérico (# 23, # 61).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/dataguard/*.py "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|no:|prohibid'; then
      echo "[FAIL] $f:$lineno contiene execute_dgmgrl sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE 'execute_dgmgrl' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara execute_dgmgrl genérico"
exit $FAIL
