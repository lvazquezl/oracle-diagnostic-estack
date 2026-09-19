#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5.5:
# JSON, Markdown AND the separately-written evidence manifest must all be free of the marker —
# escaping is not redaction, so this checks the raw file bytes, not a parsed/decoded view.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_no_secret_manifest_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/marker_combined_all_fields.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md" "manifest.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

for f in result.json report.md manifest.json; do
  if grep -qF "$MARKER" "$TMPDIR/$f"; then
    echo "[FAIL] LEAK_DETECTED field=any location=$f"
    FAIL=1
  else
    echo "[PASS] NO_LEAK location=$f"
  fi
done

exit $FAIL
