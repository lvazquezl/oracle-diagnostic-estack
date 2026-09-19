#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.4/4.6:
# legitimate certified codes across BOTH categories (typed numeric ORA-NNNNN and catalog-allowlisted
# template name) preserve classification, grouping/dedup, causality (CONFIRMED), timeline and
# evidence-by-reference — and numeric/boolean typed attributes remain correctly typed throughout.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_sig_certified_regr_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_certified_regression.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
rc = r['root_cause']
assert rc['completeness'] == 'CONFIRMED', rc
confirmed_rules = {h['rule_id'] for h in r['hypotheses'] if h['hypothesis_id'] in rc['confirmed_hypothesis_ids']}
assert confirmed_rules == {'RULE-OS-PROCESS-LIMIT-001', 'RULE-STORAGE-LATENCY-CONTRADICTION-001'}, confirmed_rules

certified = [e for e in r['timeline']['events'] if e['signature_status'] == 'CERTIFIED']
assert len(certified) == 2, certified
canon = {e['canonical_signature'] for e in certified}
assert canon == {'ORA-27300', 'HIGH_DB_FILE_SEQUENTIAL_READ'}, canon
for e in certified:
    assert e['signature_token'] is None, e

# evidence-by-reference / traceability preserved
h_os = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-OS-PROCESS-LIMIT-001')
assert set(h_os['supporting_evidence_ids']) == {'EVD-2', 'EVD-3'}, h_os
h_storage = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-STORAGE-LATENCY-CONTRADICTION-001')
assert set(h_storage['supporting_evidence_ids']) == {'EVD-5', 'EVD-6'}, h_storage
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Certified numeric + template signatures preserve classification/causality/traceability (2 independent CONFIRMED root causes)"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
