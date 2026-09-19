#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 5: toda recomendación es
# NOT_EXECUTED, y rca_engine nunca invoca subprocess/os.system ni expone execute_sql/execute_shell/
# read_file — verificado estáticamente sobre el propio código del motor, no sólo sobre su output.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

# 1) static check: rca_engine/*.py never imports subprocess/os.system, never defines
#    execute_sql/execute_shell/read_file as a public function.
for f in "$ROOT"/rca_engine/*.py; do
  if grep -qE '\bimport subprocess\b|\bos\.system\(' "$f"; then
    echo "[FAIL] $f importa subprocess u os.system"
    FAIL=1
  fi
  if grep -qE '^def (execute_sql|execute_shell|read_file)\(' "$f"; then
    echo "[FAIL] $f define una función pública prohibida (execute_sql/execute_shell/read_file)"
    FAIL=1
  fi
done

# 2) runtime check: the positive fixture's single recommendation is NOT_EXECUTED and traceable.
TMPDIR="$ROOT/tests/.tmp_rca_manual_remediation_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
assert r['recommendations'], 'expected at least one recommendation for the CONFIRMED case'
for rec in r['recommendations']:
    assert rec['execution_status'] == 'NOT_EXECUTED', rec
    assert rec['linked_to'] == r['root_cause']['rca_id']
    assert rec['precheck'] and rec['risk'] and rec['postcheck']
print('ENGINE_OK')
" 2>&1)
echo "$OUT" | grep -q "^ENGINE_OK$" || { echo "[FAIL] $OUT"; FAIL=1; }

[ $FAIL -eq 0 ] && echo "[PASS] Todas las recomendaciones son NOT_EXECUTED; el motor nunca ejecuta comandos"
exit $FAIL
