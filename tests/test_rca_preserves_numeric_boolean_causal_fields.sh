#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.7:
# integers, floats and booleans (including int 96, boolean true and boolean false) on allowlisted
# causal attributes must remain typed after sanitization — never stringified, never masked — and
# must still drive the correct causal outcome (CONFIRMED via 2 independent typed sources).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_numeric_boolean_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/numeric_boolean_types.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
# RcaResult never embeds raw attribute VALUES (only evidence_ids reference them) — so type
# preservation is verified at its actual source: sanitize_attributes()/rules.py's typed
# comparison, both exercised for real by this fixture's causal outcome. If int 96 or the booleans
# had been coerced to strings anywhere, isinstance(v, (bool,int,float)) in sanitize_attributes()
# would have dropped them and this CONFIRMED outcome would be structurally impossible.
assert r['root_cause']['completeness'] == 'CONFIRMED', r['root_cause']
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-CAPACITY-TEMP-EXHAUSTION-001')
assert h['independent_source_count'] >= 2, h
assert set(h['supporting_evidence_ids']) == {'EVD-2', 'EVD-3'}, h['supporting_evidence_ids']

# direct unit-level proof of type preservation at the actual point of sanitization.
from rca_engine.sanitize import sanitize_attributes
from rca_engine.rules import load_rules, collect_allowed_attribute_keys
from rca_engine.engine import DEFAULT_RULES_PATH
cat = load_rules(DEFAULT_RULES_PATH)
keys = collect_allowed_attribute_keys(cat)
out = sanitize_attributes({
    'tablespace_used_percent': 96, 'temp_autoextend_exhausted': True, 'storage_latency_normal': False,
}, keys)
assert out['tablespace_used_percent'] == 96 and isinstance(out['tablespace_used_percent'], int), out
assert out['temp_autoextend_exhausted'] is True, out
assert out['storage_latency_normal'] is False, out
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Numeric (int)/boolean causal fields preserved typed, correct causal outcome (CONFIRMED)"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
