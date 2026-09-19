#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.1:
# a synthetic marker placed individually in target_id, signature, attributes (key+value),
# summary and symptom_description must never survive into JSON/Markdown output — executes the
# real CLI, reports only field/location/LEAK_DETECTED-or-NO_LEAK, never the payload.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE_8f2c"

TMPDIR="$ROOT/tests/.tmp_rca_sanitize_all_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/marker_combined_all_fields.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md"
if [ "$RCA_ENGINE_RUN_RC" -ne 0 ]; then
  echo "[FAIL] rca_engine.cli exit $RCA_ENGINE_RUN_RC (expected 0 for this fixture)"
  sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"
  exit 1
fi

for field in "target_id(result.json)" "signature(result.json)" "attributes.key(result.json)" "attributes.value(result.json)" "summary(result.json)" "symptom_description(result.json)"; do
  loc="${field#*(}"; loc="${loc%)}"
  if grep -qF "$MARKER" "$TMPDIR/$loc"; then
    echo "[FAIL] LEAK_DETECTED field=$field"
    FAIL=1
  fi
done
if grep -qF "$MARKER" "$TMPDIR/report.md"; then
  echo "[FAIL] LEAK_DETECTED field=any location=report.md"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] NO_LEAK across target_id/signature/attributes(key+value)/summary/symptom_description"
exit $FAIL
