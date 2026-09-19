#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.9: negative
# test — a battery of arbitrary strings that WOULD match the old generic shape regex (or a
# plausible-looking ORA-like code with an out-of-range/unknown prefix) must never classify as
# CERTIFIED. Exercises classify_signature() directly (unit-level) for precise, unambiguous
# coverage across many inputs without needing one fixture file per case.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_sig_arbitrary_regex_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

OUT=$(rca_engine_read_json "$TMPDIR" "
from rca_engine.sanitize import classify_signature
from rca_engine.common import SignatureStatus

certified_templates = frozenset({'HIGH_DB_FILE_SEQUENTIAL_READ'})
arbitrary_regex_valid = [
    'SYNTHETIC_SECRET_DO_NOT_USE',       # the original reproduced defect
    'ANY_UPPER_SNAKE_CASE_STRING',        # generic shape, not catalog-certified
    'ATTACKER_CHOSEN_TEMPLATE_NAME',
    'FAKE-99999',                          # unknown prefix, not in the certified prefix family
    'XYZ-12345',                           # unknown prefix
    'ORA-1',                               # known prefix but too short a code (below 3 digits)
    'ORA-1234567',                         # known prefix but too long a code (above 6 digits)
    'ora-12537',                           # lowercase — grammar requires uppercase prefix
    'HIGH_DB_FILE_SEQUENTIAL_READX',       # near-miss of a real certified template, not exact
]
for s in arbitrary_regex_valid:
    status, canonical, token = classify_signature(s, 'INC-TEST-001', certified_templates)
    assert status == SignatureStatus.UNRECOGNIZED_SIGNATURE, (s, status, canonical)
    assert canonical is None, (s, canonical)
    assert canonical != s, (s, canonical)

# the ONE genuinely certified template and a genuinely certified numeric code must still pass.
status, canonical, token = classify_signature('HIGH_DB_FILE_SEQUENTIAL_READ', 'INC-TEST-001', certified_templates)
assert status == SignatureStatus.CERTIFIED and canonical == 'HIGH_DB_FILE_SEQUENTIAL_READ', (status, canonical)
status, canonical, token = classify_signature('ORA-12537', 'INC-TEST-001', certified_templates)
assert status == SignatureStatus.CERTIFIED and canonical == 'ORA-12537', (status, canonical)

print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] 9 arbitrary regex-valid strings all correctly rejected as CERTIFIED; genuine certified code/template still accepted"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
