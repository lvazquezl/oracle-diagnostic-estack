#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 3: una referencia de evidencia
# declarada pero rota/faltante impide CONFIRMED — aunque la evidencia realmente presente sea
# idéntica al caso positivo que sí confirma.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_missingref_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/missing_evidence_ref.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
em = r['evidence_manifest']
assert em['completeness'] == 'INCOMPLETE_REFS', em
assert em['missing_refs'] == ['EVD-MISSING-99'], em['missing_refs']
# same underlying evidence as the positive-confirmed fixture would otherwise CONFIRM — but the
# broken reference must cap every hypothesis below CONFIRMED.
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-OS-PROCESS-LIMIT-001')
assert h['status'] != 'CONFIRMED', h
assert r['root_cause']['completeness'] != 'CONFIRMED', r['root_cause']
assert r['root_cause']['confirmed_hypothesis_ids'] == []
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Una referencia de evidencia declarada pero faltante impide CONFIRMED"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
