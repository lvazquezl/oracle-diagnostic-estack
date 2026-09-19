#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.3/3:
# a suspicious string value injected into a typed causal attribute (nproc_utilization_percent)
# is dropped fail-closed — never coerced to a string, never echoed, and correctly prevents that
# single piece of support from contributing toward CONFIRMED.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_invalid_typed_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/invalid_typed_attribute.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

if grep -q "SYNTHETIC_SECRET_DO_NOT_USE" "$TMPDIR/result.json"; then
  echo "[FAIL] LEAK_DETECTED field=attributes.nproc_utilization_percent location=result.json"
  FAIL=1
fi

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-OS-PROCESS-LIMIT-001')
# the string-typed 'nproc_utilization_percent' must never have been accepted as supporting
# evidence -- only EVD-3 (fork_failures_observed, correctly typed) may appear.
assert 'EVD-2' not in h['supporting_evidence_ids'], h['supporting_evidence_ids']
assert h['independent_source_count'] == 1, h['independent_source_count']
assert h['status'] != 'CONFIRMED', h['status']
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Suspicious string on a typed causal field fails closed: dropped, not echoed, not CONFIRMED"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
