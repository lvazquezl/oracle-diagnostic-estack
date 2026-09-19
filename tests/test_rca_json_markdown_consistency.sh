#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 2: JSON y Markdown deben
# concordar en causa, confianza, contradicciones, impacto y referencias — el Markdown se lee
# directamente del JSON, nunca recalculado ni hardcodeado.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_consistency_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/contradiction_blocks_confirmation.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
report = open('report.md', encoding='utf-8').read()

assert r['root_cause']['completeness'] in report, 'completeness not reflected in report'
assert r['root_cause']['rca_id'] in report

for h in r['hypotheses']:
    assert h['hypothesis_id'] in report, h['hypothesis_id']
    assert h['status'] in report
    for eid in h['contradicting_evidence_ids']:
        assert eid in report, f'{eid} (contradicting) missing from report'
    for eid in h['supporting_evidence_ids']:
        assert eid in report, f'{eid} (supporting) missing from report'

for d in r['cross_domain_domains_involved']:
    assert d in report, f'domain {d} missing from cross-domain section of report'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] JSON y Markdown concuerdan en causa, hipótesis, contradicciones y dominios involucrados"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
