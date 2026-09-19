#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ningún artefacto del dominio incident
# ejecuta ALTER SYSTEM KILL SESSION ni cualquier variante ejecutable de matar sesión.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  block=$(awk '/```sql/{flag=1;next}/```/{flag=0}flag' "$f" 2>/dev/null)
  if echo "$block" | grep -Eiq '\bKILL\s+SESSION\b'; then
    echo "[FAIL] $f contiene KILL SESSION ejecutable en un bloque SQL"
    FAIL=1
  fi
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>6?lineno-6:1)),$((lineno+3))p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead|NOT_EXECUTED|forbidden_capabilities'; then
      echo "[FAIL] $f:$lineno contiene KILL SESSION sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE 'KILL SESSION' "$f")
done

grep -qi 'matar sesiones' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de matar sesiones" \
  || { echo "[FAIL] falta la prohibición explícita de matar sesiones"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident ejecuta KILL SESSION"
exit $FAIL
