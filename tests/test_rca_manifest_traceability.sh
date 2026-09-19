#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 2/3: el evidence manifest
# escrito por separado (--manifest) concuerda exactamente con el bloque evidence_manifest del JSON
# principal, y cada hipótesis referencia sólo evidence_ids realmente presentes.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_manifest_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/positive_confirmed.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "" "manifest.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }
[ -f "$TMPDIR/manifest.json" ] || { echo "[FAIL] no se generó manifest.json"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
m = json.load(open('manifest.json'))
assert m == r['evidence_manifest'], (m, r['evidence_manifest'])
assert set(m['declared_refs']) == {'EVD-1', 'EVD-2', 'EVD-3'}
assert m['missing_refs'] == []
assert m['completeness'] == 'COMPLETE'

present = set(m['present_refs'])
for h in r['hypotheses']:
    for eid in h['supporting_evidence_ids'] + h['contradicting_evidence_ids']:
        assert eid in present, f'{eid} referenced by a hypothesis but not in the evidence manifest'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] El evidence manifest separado concuerda con el JSON principal y toda referencia es trazable"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
