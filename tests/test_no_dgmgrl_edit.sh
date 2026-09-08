#!/usr/bin/env bash
# Cobertura consolidada: ningún artefacto declara ningún verbo DGMGRL de escritura (# 24) fuera
# de contexto de prohibición — complementa test_no_broker_edit.sh/test_no_broker_enable_disable.sh
# con el resto de la allowlist negativa (CONVERT/ADD/REMOVE DATABASE).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in "$ROOT"/parsers/dataguard/*.py "$ROOT/docs/DATAGUARD_BROKER_READONLY_COLLECTORS.md" "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>15?lineno-15:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead'; then
      echo "[FAIL] $f:$lineno contiene un verbo DGMGRL de escritura sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE '(CONVERT|ADD|REMOVE) DATABASE' "$f")
done

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto declara CONVERT/ADD/REMOVE DATABASE ejecutable"
exit $FAIL
