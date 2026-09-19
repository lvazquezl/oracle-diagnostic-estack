#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.1: regression
# test for the confirmed defect — a pure UPPER_SNAKE_CASE marker (SYNTHETIC_SECRET_DO_NOT_USE)
# matches the OLD generic shape regex and would have been classified CERTIFIED and echoed
# verbatim. Reproduced against the pre-fix code (documented in the closing report); this test
# guards the fix permanently: the marker must never appear in any artifact.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_sig_marker_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_pure_uppercase_marker.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md" "manifest.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

for f in result.json report.md manifest.json; do
  if grep -qF "$MARKER" "$TMPDIR/$f"; then
    echo "[FAIL] LEAK_DETECTED field=signature location=$f"
    FAIL=1
  fi
done

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
e = r['timeline']['events'][0]
assert e['signature_status'] == 'UNRECOGNIZED_SIGNATURE', e
assert e['canonical_signature'] is None, e
assert e['signature_token'] and e['signature_token'].startswith('SIG-'), e
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] A generic-shape-matching marker is never CERTIFIED and never echoed — classified UNRECOGNIZED_SIGNATURE with an opaque token"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
