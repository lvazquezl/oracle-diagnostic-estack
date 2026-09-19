#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.10:
# regression — evidencia contradictoria, insuficiente y temporalidad-sin-causalidad siguen
# impidiendo confirmar indebidamente una causa DESPUÉS del rediseño del sanitizador (attribute
# allowlisting, tokenización, normalización de signature). Reutiliza los fixtures del hardening
# de ejecución RCA anterior para probar que el rediseño de seguridad no relajó la causalidad.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0

check_never_confirmed() {
  local fixture="$1" label="$2"
  local tmpdir="$ROOT/tests/.tmp_rca_no_false_rc_${label}_$$"
  mkdir -p "$tmpdir"
  cp "$ROOT/tests/fixtures/rca_engine/$fixture" "$tmpdir/fixture.json"
  rca_engine_run "$tmpdir" "fixture.json" "" "" "result.json"
  if [ "$RCA_ENGINE_RUN_RC" -ne 0 ]; then
    echo "[FAIL] $label: exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; FAIL=1
    rm -rf "$tmpdir"; return
  fi
  local completeness
  completeness=$(rca_engine_read_json "$tmpdir" "
import json
print(json.load(open('result.json'))['root_cause']['completeness'])
")
  if [ "$completeness" = "CONFIRMED" ]; then
    echo "[FAIL] $label: root_cause.completeness=CONFIRMED (must never be CONFIRMED)"
    FAIL=1
  else
    echo "[PASS] $label: root_cause.completeness=$completeness (correctly not CONFIRMED)"
  fi
  rm -rf "$tmpdir"
}

check_never_confirmed "contradiction_blocks_confirmation.json" "critical_contradiction"
check_never_confirmed "negative_temporal_proximity.json" "temporal_proximity_only"
check_never_confirmed "symptom_not_root_cause.json" "insufficient_evidence"
check_never_confirmed "missing_evidence_ref.json" "missing_evidence_ref"

[ $FAIL -eq 0 ] && echo "[PASS] Causality gates unaffected by the sanitization redesign: no false CONFIRMED in any regression case"
exit $FAIL
