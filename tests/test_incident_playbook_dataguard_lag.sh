#!/usr/bin/env bash
# PHASE 11 — INCIDENT ANALYSIS & ROOT CAUSE AUTOMATION: playbook de Data Guard lag/gap —
# referenciado en el Incident Playbook Model y respaldado por los fixtures de transport/apply lag.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
DOC="$ROOT/docs/INCIDENT_PLAYBOOK_MODEL.md"
F1="$ROOT/tests/fixtures/incident/dataguard/transport-lag.txt"
F2="$ROOT/tests/fixtures/incident/dataguard/apply-lag.txt"

for f in "$F1" "$F2"; do
  [ -f "$f" ] || { echo "[FAIL] falta el fixture $f"; FAIL=1; }
done

grep -qi 'Data Guard lag/gap' "$DOC" \
  && echo "[PASS] docs/INCIDENT_PLAYBOOK_MODEL.md cubre Data Guard lag/gap" \
  || { echo "[FAIL] falta la cobertura de Data Guard lag/gap"; FAIL=1; }

grep -q 'incident/dataguard-correlation' "$DOC" \
  && echo "[PASS] playbook referencia incident/dataguard-correlation" \
  || { echo "[FAIL] falta la referencia a incident/dataguard-correlation"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Playbook de Data Guard lag consistente"
exit $FAIL
