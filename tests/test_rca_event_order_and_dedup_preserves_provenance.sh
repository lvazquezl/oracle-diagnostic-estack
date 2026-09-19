#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 3: deduplicación conserva
# count/first_seen/last_seen e IDs de fuente — eventos idénticos dentro de la ventana de dedup se
# fusionan, eventos distintos fuera de la ventana permanecen separados y ordenados.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_dedup_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/event_order_dedup.json" "$TMPDIR/fixture.json"
echo '{"dedup_window_seconds": 1}' > "$TMPDIR/policy.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "policy.json" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
events = r['timeline']['events']
# EVD-1 (14:22:07.1) and EVD-2 (14:22:07.4) are the same signature/source within 1s -> one merged
# event with count=2, both evidence_ids preserved. EVD-3 (14:25:41) is outside the window -> a
# distinct second event with count=1.
assert len(events) == 2, [e['event_key'] for e in events]
merged = next(e for e in events if e['count'] == 2)
distinct = next(e for e in events if e['count'] == 1)
assert set(merged['evidence_ids']) == {'EVD-1', 'EVD-2'}, merged
assert merged['first_seen'].startswith('2026-03-11T14:22:07')
assert merged['last_seen'].startswith('2026-03-11T14:22:07')
assert merged['first_seen'] <= merged['last_seen']
assert distinct['evidence_ids'] == ['EVD-3']
# stable chronological order: merged event comes before the distinct later one
assert events.index(merged) < events.index(distinct)
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Dedup conserva count/first_seen/last_seen/evidence_ids, orden cronológico estable"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
