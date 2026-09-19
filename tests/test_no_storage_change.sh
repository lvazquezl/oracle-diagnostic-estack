#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: ningún artefacto del dominio incident
# extiende/modifica storage/ASM/tablespace/filesystem.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='ALTER\s+TABLESPACE.*ADD\s+DATAFILE|ALTER\s+DISKGROUP.*ADD\s+DISK|resize2fs|lvextend|ALTER DATABASE DATAFILE.*RESIZE'

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  while IFS=: read -r lineno _; do
    [ -z "$lineno" ] && continue
    window=$(sed -n "$((lineno>3?lineno-3:1)),${lineno}p" "$f")
    if ! echo "$window" | grep -qiE 'nunca|ningun|ningún|never|prohibid|bloquead|NOT_EXECUTED'; then
      echo "[FAIL] $f:$lineno contiene un patrón de cambio de storage sin contexto de prohibición"
      FAIL=1
    fi
  done < <(grep -niE "$PATTERN" "$f")
done

grep -qi 'modificar OS/red/storage/seguridad' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de cambio de storage" \
  || { echo "[FAIL] falta la prohibición explícita de cambio de storage"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident modifica storage/ASM/tablespace/filesystem"
exit $FAIL
