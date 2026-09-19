#!/usr/bin/env bash
# Ningún artefacto ejecuta failover — ni ALTER DATABASE FAILOVER ni DGMGRL FAILOVER TO.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/queries/dataguard" -name 'Q-*.md' 2>/dev/null) "$ROOT"/parsers/dataguard/*.py "$ROOT/mcp/tool-manifest.md"; do
  [ -f "$f" ] || continue
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f" 2>/dev/null)
  if echo "$block" | grep -Eiq '\bFAILOVER\b'; then
    echo "[FAIL] $f contiene FAILOVER ejecutable en un bloque SQL"
    FAIL=1
  fi
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead|NOT_EXECUTED'; then
      echo "[FAIL] $f:$lineno contiene FAILOVER TO sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE 'FAILOVER TO' "$f")
done

grep -q 'ALTER DATABASE SWITCHOVER/FAILOVER' "$ROOT/agents/oracle-dataguard-analyst/manifest.yaml" \
  && echo "[PASS] manifest.yaml prohíbe explícitamente failover" \
  || { echo "[FAIL] falta prohibición explícita"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto ejecuta failover"

# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION (NO FAILOVER/SWITCHOVER EXECUTION).
MI="$ROOT/agents/incident-root-cause-analyst/manifest.yaml"
[ -f "$MI" ] || { echo "[FAIL] falta $MI"; FAIL=1; }
if [ -f "$MI" ]; then
  grep -qi 'ejecutar failover o switchover de Data Guard' "$MI" \
    && echo "[PASS] incident-root-cause-analyst declara la prohibición de ejecutar failover" \
    || { echo "[FAIL] falta la prohibición de failover en incident-root-cause-analyst"; FAIL=1; }
fi

exit $FAIL
