#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.5: two events
# reporting the SAME unrecognized signature (from different sources) correlate via the identical
# opaque token; a third event with a genuinely DIFFERENT unrecognized signature must never
# collide with that token.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_sig_token_corr_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_token_correlation.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

if grep -qF "$MARKER" "$TMPDIR/result.json"; then
  echo "[FAIL] LEAK_DETECTED field=signature location=result.json"
  FAIL=1
fi

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
by_evd = {}
for e in r['timeline']['events']:
    for eid in e['evidence_ids']:
        by_evd[eid] = e['signature_token']
assert by_evd['EVD-1'] == by_evd['EVD-2'], by_evd   # same raw signature, different sources -> same token
assert by_evd['EVD-3'] != by_evd['EVD-1'], by_evd   # genuinely different raw signature -> different token, no collision
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Same unknown signature correlates via identical token across sources; distinct signatures never collide"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
