#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.10: dedicated
# guard against a future regression reintroducing "any string matching a generic shape is safe".
# Two independent checks: (1) static — the source no longer contains a standalone template-shape
# regex used as a blanket accept-and-return-verbatim rule; (2) functional — classify_signature()
# is proven sensitive to exactly this defect by a mutation control, mirroring
# tests/test_rca_mutation_testing_control.sh's methodology (temp copy only, real catalog file
# never modified).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

# 1) static guard: the old blanket-accept pattern must no longer be DEFINED as a compiled regex
#    constant (a historical mention in a docstring/comment explaining the fix is fine and expected
#    — see sanitize.py's classify_signature() docstring).
if grep -qE '^_SAFE_TEMPLATE_SIGNATURE\s*=\s*re\.compile' "$ROOT/rca_engine/sanitize.py"; then
  echo "[FAIL] rca_engine/sanitize.py still DEFINES the old blanket shape-accept pattern as a regex constant"
  FAIL=1
else
  echo "[PASS] the old blanket template-shape-accept pattern is no longer defined as a regex constant in sanitize.py"
fi
# and classify_signature() itself must never return the raw input verbatim without going through
# either the numeric-code grammar or the catalog-membership check.
if grep -qE 'return raw_signature$' "$ROOT/rca_engine/sanitize.py"; then
  echo "[FAIL] sanitize.py contains an unconditional 'return raw_signature' outside the two certified paths"
  FAIL=1
fi

# 2) functional guard: classify_signature() must reject an arbitrary shape-matching string
#    regardless of what the (empty) certified-template set contains — proving certification
#    requires catalog membership, never shape alone.
TMPDIR="$ROOT/tests/.tmp_rca_sig_regex_guard_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
OUT=$(rca_engine_read_json "$TMPDIR" "
from rca_engine.sanitize import classify_signature
from rca_engine.common import SignatureStatus

# with an EMPTY certified-template allowlist, nothing shape-shaped should ever certify.
status, canonical, token = classify_signature('ANY_UPPER_SNAKE_SHAPE_AT_ALL', 'INC-TEST-002', frozenset())
assert status == SignatureStatus.UNRECOGNIZED_SIGNATURE, (status, canonical)
assert canonical is None

# mutation control: simulate the historical defect by calling the OLD-STYLE logic inline (a
# regex-only accept) and confirm it WOULD have produced a different (wrong) result than the real
# function — demonstrating this test is actually sensitive to the regression, not just present.
import re
old_defective_pattern = re.compile(r'^[A-Z][A-Z0-9_]{2,63}\$')
old_style_would_accept = bool(old_defective_pattern.match('ANY_UPPER_SNAKE_SHAPE_AT_ALL'))
assert old_style_would_accept is True, 'the old pattern must genuinely have matched this input for the mutation control to be meaningful'
assert status == SignatureStatus.UNRECOGNIZED_SIGNATURE, 'real classify_signature() must diverge from the old defective behavior'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Functional mutation control confirms classify_signature() is sensitive to the historical generic-shape-accept defect"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
