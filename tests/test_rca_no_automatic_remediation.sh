#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.12:
# the new tokenization/sanitization modules add no execution capability whatsoever — every
# recommendation remains NOT_EXECUTED, and rca_engine/tokenization.py + the rewritten
# rca_engine/sanitize.py/intake.py never import subprocess, never call os.system, and define no
# execute_sql/execute_shell/read_file public function.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

for f in "$ROOT"/rca_engine/*.py; do
  if grep -qE '\bimport subprocess\b|\bos\.system\(' "$f"; then
    echo "[FAIL] $f imports subprocess or calls os.system"
    FAIL=1
  fi
  if grep -qE '^def (execute_sql|execute_shell|read_file)\(' "$f"; then
    echo "[FAIL] $f defines a prohibited public function (execute_sql/execute_shell/read_file)"
    FAIL=1
  fi
done

TMPDIR="$ROOT/tests/.tmp_rca_no_auto_remediation_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
assert r['root_cause']['completeness'] == 'CONFIRMED', r['root_cause']
assert r['recommendations'], 'expected at least one recommendation'
for rec in r['recommendations']:
    assert rec['execution_status'] == 'NOT_EXECUTED', rec
print('ENGINE_OK')
" 2>&1)
echo "$OUT" | grep -q "^ENGINE_OK$" || { echo "[FAIL] $OUT"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] No automatic remediation: all recommendations NOT_EXECUTED, no execution capability added by this hardening"
exit $FAIL
