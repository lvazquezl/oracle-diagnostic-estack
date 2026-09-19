#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 4.6: separar el efecto del
# incidente, factores contribuyentes y la acción que restauró el servicio — una mitigación exitosa
# (evento RECOVERY) no demuestra la causa por sí sola. Verifica estructuralmente que un evento
# RECOVERY, aunque declare atributos que coincidirían con una condición de la regla, nunca puede
# satisfacer esa condición (CAUSAL_ELIGIBLE_EVENT_TYPES excluye RECOVERY por diseño).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_mitigation_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/mitigation_not_root_cause.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
# EVD-2 is a RECOVERY event whose attributes (listener_process_responsive=false,
# listener_thread_count_anomalous=true) would otherwise satisfy RULE-NET-LISTENER-HANG-001's
# supporting_conditions — it must NEVER be counted, because a recovery action restoring service
# never proves the cause it mitigated.
for h in r['hypotheses']:
    assert 'EVD-2' not in h['supporting_evidence_ids'], (
        'RECOVERY event counted as supporting causal evidence: ' + str(h)
    )
    assert 'EVD-2' not in h['contradicting_evidence_ids']
# With only the bare symptom (EVD-1) causally eligible, the hypothesis cannot be confirmed.
assert r['root_cause']['completeness'] != 'CONFIRMED', r['root_cause']
# The RECOVERY event must still appear in the timeline — excluded from causal matching, not from
# the incident record.
timeline_ids = set()
for e in r['timeline']['events']:
    timeline_ids.update(e['evidence_ids'])
assert 'EVD-2' in timeline_ids, 'RECOVERY event must still be reported in the timeline'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Un evento RECOVERY nunca satisface una condición causal, pese a declarar atributos coincidentes"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
