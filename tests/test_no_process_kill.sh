#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ningún artefacto del dominio incident
# ejecuta kill/taskkill/pkill de proceso OS.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='\bkill -9\b|\btaskkill\b|\bpkill\b|os\.kill\('

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' -o -name '*.py' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>6?lineno-6:1)),$((lineno+3))p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|forbidden|NOT_EXECUTED|forbidden_capabilities'; then
      echo "[FAIL] $f:$lineno contiene un patrón de kill de proceso sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -nE "$PATTERN" "$f")
done

grep -qi 'procesos (kill/taskkill)' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de matar procesos" \
  || { echo "[FAIL] falta la prohibición explícita de matar procesos"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident ejecuta kill de proceso OS"
exit $FAIL
