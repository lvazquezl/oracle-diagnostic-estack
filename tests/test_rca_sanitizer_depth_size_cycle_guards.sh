#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 3/5.8:
# excessive depth, excessive size, and a genuine Python reference cycle (only reachable by calling
# the sanitizer directly with a raw object, as a real JSON fixture can never encode a cycle) all
# fail closed with SanitizationError — never a crash, never a partial/silent truncation presented
# as success, never an unbounded resource consumption.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_depth_size_cycle_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

OUT=$(rca_engine_read_json "$TMPDIR" "
from rca_engine.sanitize import deep_sanitize, SanitizationError, MAX_DEPTH, MAX_LIST_LEN, MAX_DICT_KEYS

# 1) excessive depth
deep = current = {}
for _ in range(MAX_DEPTH + 5):
    current['n'] = {}
    current = current['n']
try:
    deep_sanitize(deep)
    raise AssertionError('excessive depth was NOT rejected')
except SanitizationError:
    pass

# 2) excessive list length is truncated (not rejected) — verify the bound is actually enforced
big_list = list(range(MAX_LIST_LEN + 500))
result = deep_sanitize(big_list)
assert len(result) <= MAX_LIST_LEN, len(result)

# 3) excessive dict key count is rejected
big_dict = {f'k{i}': i for i in range(MAX_DICT_KEYS + 50)}
try:
    deep_sanitize(big_dict)
    raise AssertionError('excessive key count was NOT rejected')
except SanitizationError:
    pass

# 4) genuine Python reference cycle — only possible via direct object construction, never via
#    json.load() (JSON cannot encode a cycle) — the sanitizer must still fail closed, not hang or
#    crash with RecursionError/MemoryError.
cyclic = {}
cyclic['self'] = cyclic
try:
    deep_sanitize(cyclic)
    raise AssertionError('cyclic structure was NOT rejected')
except SanitizationError:
    pass

# 5) unsupported type (a raw Python object, never JSON-representable) fails closed too.
class Weird:
    pass
try:
    deep_sanitize(Weird())
    raise AssertionError('unsupported type was NOT rejected')
except SanitizationError:
    pass

print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Depth/size/cycle/unsupported-type guards all fail closed, never crash or silently succeed"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
