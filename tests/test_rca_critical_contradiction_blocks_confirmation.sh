#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 4.3: una contradicción crítica
# impide CONFIRMED aunque haya evidencia de soporte real — nunca resuelta automáticamente.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_contradiction_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/contradiction_blocks_confirmation.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
if [ "$RCA_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] rca_engine.cli terminó con código $RCA_ENGINE_RUN_RC — stderr:"
  sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"
  exit 1
fi

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-STORAGE-LATENCY-CONTRADICTION-001')
assert h['supporting_evidence_ids'], 'expected real supporting evidence present'
assert h['contradicting_evidence_ids'] == ['EVD-3'], h['contradicting_evidence_ids']
assert h['unresolved_critical_contradiction'] is True
assert h['status'] in ('WEAKENED', 'REJECTED'), h['status']
assert h['status'] != 'CONFIRMED'
assert r['root_cause']['completeness'] != 'CONFIRMED', r['root_cause']
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Contradicción crítica (iostat normal) bloquea CONFIRMED pese a evidencia de soporte real"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
