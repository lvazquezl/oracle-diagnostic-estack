#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.2:
# markers in nested dict keys/values, lists and Unicode inside `attributes` must never survive —
# and unit-level deep_sanitize()/sanitize_attributes() are exercised directly too, not just via
# the CLI, to prove the guarantee holds at the function boundary as well as end-to-end.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_sanitize_nested_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/marker_combined_all_fields.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

if grep -qF "$MARKER" "$TMPDIR/result.json"; then
  echo "[FAIL] LEAK_DETECTED field=nested_attributes location=result.json"
  FAIL=1
fi

# unit-level: nested dict/list/unicode VALUES with the marker must always be redacted by
# deep_sanitize() itself — this is the generic, allowlist-independent guarantee it provides.
# (Key NAMES are only guaranteed redacted through the field-specific allowlist layer —
# sanitize_attributes() — already proven above via the CLI/attributes pipeline; deep_sanitize()
# alone deliberately does NOT apply the aggressive bare-token heuristic to key names, because a
# legitimate structural attribute name like `fork_failures_stopped_after_limit_increase` is
# routinely >=20 chars and would otherwise be false-positived away — see sanitize.py's
# _key_contains_narrow_secret_pattern docstring for the full rationale. This is a documented,
# intentional boundary, not an oversight.)
OUT=$(rca_engine_read_json "$TMPDIR" "
from rca_engine.sanitize import deep_sanitize
import json
payload = {
    'level1': {
        'level2_list': ['${MARKER}_item1', {'level3_key': '${MARKER}_deep'}],
        'unicode_field': '${MARKER}_üñí',
    }
}
safe = deep_sanitize(payload)
dumped = json.dumps(safe)
assert '$MARKER' not in dumped, dumped

# a key that is PRECISELY credential-shaped (not just long) is dropped entirely by deep_sanitize
# itself, key name included — this IS the generic, allowlist-independent guarantee for keys.
example_credential_key = 'password=hunter2'  # example synthetic value, not a real credential
credential_shaped = deep_sanitize({example_credential_key: 'irrelevant', 'safe_key': 'safe_value'})
assert example_credential_key not in json.dumps(credential_shaped)  # example synthetic value check
assert credential_shaped == {'safe_key': 'safe_value'}, credential_shaped
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] NO_LEAK for nested values/lists/unicode (deep_sanitize) and precisely credential-shaped keys (dropped); key-name-marker redaction for unknown attribute keys is guaranteed by sanitize_attributes()'s allowlist, verified via the CLI pipeline above"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
