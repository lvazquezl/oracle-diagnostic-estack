#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: incident/rman-correlation y el resto del
# dominio incident nunca ejecutan RMAN (BACKUP/RESTORE/RECOVER/DELETE/CROSSCHECK/CONFIGURE/CATALOG).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
PATTERN='^\s*(BACKUP|RESTORE|RECOVER|DELETE|CROSSCHECK|CONFIGURE|CATALOG|DUPLICATE)\s'

for f in $(find "$ROOT/skills/incident" "$ROOT/agents/incident-root-cause-analyst" -type f \( -name '*.md' -o -name '*.yaml' \) 2>/dev/null); do
  [ -f "$f" ] || continue
  block=$(awk '/```(rman|text)?$/{flag=1;next}/```/{flag=0}flag' "$f" 2>/dev/null)
  if echo "$block" | grep -Eiq "$PATTERN"; then
    echo "[FAIL] $f contiene un comando RMAN ejecutable"
    FAIL=1
  fi
done

grep -qi 'ejecutar RMAN' "$ROOT/agents/incident-root-cause-analyst/manifest.yaml" \
  && echo "[PASS] incident-root-cause-analyst declara explícitamente la prohibición de ejecutar RMAN" \
  || { echo "[FAIL] falta la prohibición explícita de ejecutar RMAN"; FAIL=1; }

grep -qi 'nunca ejecuta RMAN' "$ROOT/skills/incident/rman-correlation/SKILL.md" \
  && echo "[PASS] incident/rman-correlation declara explícitamente que nunca ejecuta RMAN" \
  || { echo "[FAIL] falta la prohibición explícita en incident/rman-correlation/SKILL.md"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Ningún artefacto de incident ejecuta RMAN"
exit $FAIL
