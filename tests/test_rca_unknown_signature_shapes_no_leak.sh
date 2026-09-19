#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.2: unknown
# signatures with valid-looking format, mixed case, Unicode, spaces, newlines, quotes, backslashes
# and very long strings must never be reflected literally in any artifact.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_sig_shapes_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_various_unknown_shapes.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

for f in result.json report.md; do
  if grep -qF "$MARKER" "$TMPDIR/$f"; then
    echo "[FAIL] LEAK_DETECTED field=signature location=$f"
    FAIL=1
  fi
done

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
assert len(r['timeline']['events']) == 8, len(r['timeline']['events'])
for e in r['timeline']['events']:
    assert e['signature_status'] == 'UNRECOGNIZED_SIGNATURE', e
    assert e['canonical_signature'] is None, e
    assert e['signature_token'] and e['signature_token'].startswith('SIG-'), e
    assert len(e['signature_token']) == len('SIG-') + 16, e   # fixed-length token regardless of input length/shape
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] 8 differently-shaped unknown signatures (mixed case/Unicode/spaces/newline/quotes/backslash/very-long) all classified UNRECOGNIZED_SIGNATURE with fixed-length opaque tokens, never echoed"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
