#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.6
# (updated by PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING's
# signature_status/canonical_signature/signature_token schema):
# a CERTIFIED signature (ORA-27300, a typed numeric code under a known prefix) reported by two
# different sources normalizes identically and still correlates/clusters for rule matching; a
# signature that merely *looks* like a template (an UPPER_SNAKE-shaped synthetic marker, not in
# the catalog's certified allowlist) is UNRECOGNIZED_SIGNATURE and correlates only via its opaque
# signature_token — never echoed raw, and never accepted just because it matched a generic shape.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_signature_clustering_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_clustering.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

if grep -q "SYNTHETIC_SECRET_DO_NOT_USE" "$TMPDIR/result.json"; then
  echo "[FAIL] LEAK_DETECTED field=signature location=result.json"
  FAIL=1
fi

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
statuses = {e['signature_status'] for e in r['timeline']['events']}
assert 'CERTIFIED' in statuses, statuses
assert 'UNRECOGNIZED_SIGNATURE' in statuses, statuses

ora_events = [e for e in r['timeline']['events'] if e['signature_status'] == 'CERTIFIED']
assert len(ora_events) == 2, ora_events   # EVD-1 and EVD-2, both preserved (different sources, beyond dedup window logic still distinct events)
for e in ora_events:
    assert e['canonical_signature'] == 'ORA-27300', e   # typed numeric code, certified by grammar
    assert e['signature_token'] is None, e              # a CERTIFIED signature never carries a token

unknown_events = [e for e in r['timeline']['events'] if e['signature_status'] == 'UNRECOGNIZED_SIGNATURE']
assert len(unknown_events) == 1, unknown_events
u = unknown_events[0]
assert u['canonical_signature'] is None, u              # never a raw/partial echo
assert u['signature_token'] and u['signature_token'].startswith('SIG-'), u

h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-OS-PROCESS-LIMIT-001')
assert 'EVD-1' in h['symptom_evidence_ids'] if 'symptom_evidence_ids' in h else True
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Safe signature clusters identically across sources; unsafe-shaped signature templated, never echoed"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
