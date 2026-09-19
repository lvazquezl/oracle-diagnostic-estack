#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de RMAN backup failure —
# referenciado en el Incident Playbook Model, respaldado por fixtures de channel/SBT failure.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
F1="$ROOT/tests/fixtures/incident/rman/channel-exhaustion.txt"
F2="$ROOT/tests/fixtures/incident/rman/sbt-media-manager-failure.txt"

for f in "$F1" "$F2"; do
  [ -f "$f" ] || { echo "[FAIL] falta el fixture $f"; FAIL=1; }
done

grep -qi 'RMAN backup failure' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre RMAN backup failure" \
  || { echo "[FAIL] falta la cobertura de RMAN backup failure"; FAIL=1; }

grep -qi 'read-only, diagnose-and-recommend only' "$DOC" \
  && echo "[PASS] principio read-only aplica también al playbook RMAN" \
  || { echo "[FAIL] falta el principio read-only en el playbook RMAN"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de RMAN backup failure consistente"
exit $FAIL
