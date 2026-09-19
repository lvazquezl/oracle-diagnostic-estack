#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.6:
# same raw target_id within the same incident -> same token; different target_id -> different
# token; same raw target_id under a DIFFERENT incident -> different token (no cross-incident
# correlation without explicit authorization). Also confirms the raw value never appears.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_target_token_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
for f in target_token_same_incident_a target_token_same_incident_b target_token_different_target target_token_different_incident; do
  cp "$ROOT/tests/fixtures/rca_engine/$f.json" "$TMPDIR/$f.json"
  rca_engine_run "$TMPDIR" "$f.json" "" "" "${f}.out.json"
  [ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] $f: exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }
done

for f in target_token_same_incident_a target_token_same_incident_b target_token_different_target target_token_different_incident; do
  if grep -qE "T-SHARED-TARGET|T-DIFFERENT-TARGET" "$TMPDIR/${f}.out.json"; then
    echo "[FAIL] LEAK_DETECTED field=target_id location=${f}.out.json"
    FAIL=1
  fi
done

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
a = json.load(open('target_token_same_incident_a.out.json'))['target_id']
b = json.load(open('target_token_same_incident_b.out.json'))['target_id']
c = json.load(open('target_token_different_target.out.json'))['target_id']
d = json.load(open('target_token_different_incident.out.json'))['target_id']
assert a.startswith('TGT-'), a
assert a == b, (a, b)               # same incident, same raw target_id -> same token
assert a != c, (a, c)               # same incident, different raw target_id -> different token
assert a != d, (a, d)               # different incident, same raw target_id -> different token (no cross-incident correlation)
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] target_id tokenization: stable within an incident, distinct across targets/incidents, raw value never leaked"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
