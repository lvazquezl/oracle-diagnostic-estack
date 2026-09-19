#!/usr/bin/env bash
# PHASE 11 — RCA EXECUTION & EVIDENCE VALIDATION HARDENING, sección 5: la salida enumera los
# dominios y referencias reales involucrados en un escenario cross-domain (RAC/OS/Network).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

TMPDIR="$ROOT/tests/.tmp_rca_crossdomain_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/cross_domain_rac_os_network.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r = json.load(open('result.json'))
assert set(r['cross_domain_domains_involved']) == {'rac', 'os', 'network'}, r['cross_domain_domains_involved']
h = next(h for h in r['hypotheses'] if h['rule_id'] == 'RULE-RAC-INTERCONNECT-001')
assert set(h['supporting_evidence_ids']) == {'EVD-2', 'EVD-3'}, h['supporting_evidence_ids']
assert h['status'] == 'CONFIRMED', h['status']
assert r['root_cause']['completeness'] == 'CONFIRMED'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] La salida enumera los 3 dominios (rac/os/network) y sus referencias reales de evidencia"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

exit $FAIL
