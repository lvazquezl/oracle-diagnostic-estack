#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 4 "Caso E2E positivo":
# fixture sintético con evidencia de límite de procesos, agotamiento medido, fallo de creación de
# procesos y correlación temporal produce un RCA CONFIRMED respaldado por IDs verificables.
# Ejercita rca_engine.cli end-to-end (LOCAL_RUNTIME_TESTED) — no busca texto en Markdown, ejecuta
# el motor real.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_e2e_confirmed_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md" "manifest.json"
if [ "$RCA_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] rca_engine.cli terminó con código $RCA_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"
  exit 1
fi
[ -f "$TMPDIR/result.json" ] || { echo "[FAIL] no se generó result.json"; exit 1; }
[ -f "$TMPDIR/report.md" ] || { echo "[FAIL] no se generó report.md"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
rc = r['root_cause']

assert rc['completeness'] == 'CONFIRMED', rc
assert rc['confirmed_hypothesis_ids'] == ['HYP-INC-20260311-001-RULE-OS-PROCESS-LIMIT-001'], rc['confirmed_hypothesis_ids']

confirmed = [h for h in r['hypotheses'] if h['hypothesis_id'] in rc['confirmed_hypothesis_ids']]
assert len(confirmed) == 1
h = confirmed[0]
assert h['status'] == 'CONFIRMED', h['status']
assert set(h['supporting_evidence_ids']) == {'EVD-2', 'EVD-3'}, h['supporting_evidence_ids']
assert h['contradicting_evidence_ids'] == []
assert h['independent_source_count'] >= 2
assert h['unresolved_critical_contradiction'] is False
assert len(h['causal_chain']) >= 3

assert r['evidence_manifest']['completeness'] == 'COMPLETE'
assert len(r['recommendations']) == 1
assert r['recommendations'][0]['execution_status'] == 'NOT_EXECUTED'
assert r['recommendations'][0]['linked_to'] == rc['rca_id']
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Fixture positivo (process-limit exhaustion) produce RCA CONFIRMED con IDs de evidencia verificables"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
