#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de FRA pressure — referenciado en
# el Incident Playbook Model y respaldado por el fixture fra-pressure-backup-failure.txt.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
FIXTURE="$ROOT/tests/fixtures/incident/rman/fra-pressure-backup-failure.txt"

[ -f "$FIXTURE" ] || { echo "[FAIL] falta el fixture $FIXTURE"; FAIL=1; }

grep -qi 'FRA pressure' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre FRA pressure" \
  || { echo "[FAIL] falta la cobertura de FRA pressure"; FAIL=1; }

grep -q 'incident/asm-storage-correlation' "$DOC" && grep -q 'incident/rman-correlation' "$DOC" \
  && echo "[PASS] playbook referencia incident/asm-storage-correlation e incident/rman-correlation" \
  || { echo "[FAIL] falta alguna referencia cruzada del playbook de FRA"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de FRA pressure consistente"
exit $FAIL
