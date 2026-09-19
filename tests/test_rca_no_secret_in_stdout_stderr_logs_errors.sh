#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.4:
# validation/parsing/CLI errors induced by malformed input must never echo the raw offending
# value on stdout or stderr — checked across 4 distinct induced-error fixtures.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"
MARKER2="SYNTHETIC-SECRET-DO-NOT-USE"

TMPDIR="$ROOT/tests/.tmp_rca_no_secret_errors_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT

check_case() {
  local fixture="$1" label="$2"
  cp "$ROOT/tests/fixtures/rca_engine/$fixture" "$TMPDIR/$fixture"
  rca_engine_run "$TMPDIR" "$fixture" "" "" "${fixture}.out"
  if [ "$RCA_ENGINE_RUN_RC" -eq 0 ]; then
    echo "[FAIL] $label: expected non-zero exit, got 0"
    FAIL=1
    return
  fi
  if grep -qE "$MARKER|$MARKER2" "$RCA_ENGINE_RUN_STDERR_FILE"; then
    echo "[FAIL] LEAK_DETECTED field=$label location=stderr"
    FAIL=1
  else
    echo "[PASS] NO_LEAK location=stderr case=$label (exit $RCA_ENGINE_RUN_RC)"
  fi
  [ -f "$TMPDIR/${fixture}.out" ] && { echo "[FAIL] $label: output file written despite rejection"; FAIL=1; }
}

check_case "malformed_multi_error.json" "invalid_domain"
check_case "malformed_bad_event_type.json" "invalid_event_type"
check_case "malformed_duplicate_evidence_id.json" "duplicate_evidence_id"
check_case "malformed_secret_shaped_evidence_id.json" "secret_shaped_evidence_id"

# a syntactically-broken (non-JSON) fixture, with a marker embedded in the broken content, must
# also never echo the marker in the JSON-decode error message.
printf '{ "incident": { "id": "%s", broken json here' "$MARKER" > "$TMPDIR/broken.json"
rca_engine_run "$TMPDIR" "broken.json" "" "" "broken.out"
if [ "$RCA_ENGINE_RUN_RC" -eq 0 ]; then
  echo "[FAIL] broken JSON: expected non-zero exit"
  FAIL=1
elif grep -qF "$MARKER" "$RCA_ENGINE_RUN_STDERR_FILE"; then
  echo "[FAIL] LEAK_DETECTED field=broken_json location=stderr"
  FAIL=1
else
  echo "[PASS] NO_LEAK location=stderr case=broken_json (exit $RCA_ENGINE_RUN_RC)"
fi

exit $FAIL
