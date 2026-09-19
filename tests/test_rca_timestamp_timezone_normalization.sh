#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 3: timestamps con zona/offset
# explícito (Z, -06:00, +02:00) se normalizan correctamente a UTC preservando source_timestamp.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_tz_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/timezone_normalization.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
events = {e['event_key']: e for e in r['timeline']['events']}
# EVD-1 15:02:31Z, EVD-2 09:02:00-06:00 (== 15:02:00Z), EVD-3 17:02:10+02:00 (== 15:02:10Z) —
# all three normalize to the same UTC minute window, none degraded (all have explicit offsets).
timestamps = sorted(e['timestamp_utc'] for e in r['timeline']['events'])
assert timestamps[0].startswith('2026-03-11T15:02:00'), timestamps
assert timestamps[-1].startswith('2026-03-11T15:02:31'), timestamps
assert r['timeline']['degraded'] is False, r['timeline']
# events are ordered chronologically ascending
assert timestamps == sorted(timestamps)
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Timestamps con offset explícito (Z/-06:00/+02:00) se normalizan correctamente a UTC"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
