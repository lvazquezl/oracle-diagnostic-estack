#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.7: a
# validation error induced by an unrelated malformed field (missing timestamp) on an evidence item
# that ALSO carries a signature marker must never echo that marker into the CLI's error output.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE_ERRORPATH"

TMPDIR="$ROOT/tests/.tmp_rca_sig_error_paths_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_malformed_error_case.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json"
if [ "$RCA_ENGINE_RUN_RC" -eq 0 ]; then
  echo "[FAIL] expected non-zero exit for missing evidence.timestamp"
  FAIL=1
elif grep -qF "$MARKER" "$RCA_ENGINE_RUN_STDERR_FILE"; then
  echo "[FAIL] LEAK_DETECTED field=signature location=stderr"
  FAIL=1
else
  echo "[PASS] Malformed-input error (exit $RCA_ENGINE_RUN_RC) never echoes the co-located signature marker"
fi
[ -f "$TMPDIR/result.json" ] && { echo "[FAIL] output file written despite rejection"; FAIL=1; }

exit $FAIL
