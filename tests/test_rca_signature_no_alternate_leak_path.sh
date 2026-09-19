#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.3: a marker
# placed in `signature` AND simultaneously in `attributes` (key+value+nested) and `summary` must
# not be reintroduced through any of those other routes — confirming the signature fix did not
# leave, or create, an alternate exposure path.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE_SIGFIELD"

TMPDIR="$ROOT/tests/.tmp_rca_sig_alt_path_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_marker_nested_paths.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md" "manifest.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

for f in result.json report.md manifest.json "$RCA_ENGINE_RUN_STDERR_FILE"; do
  if grep -qF "$MARKER" "$f" 2>/dev/null; then
    echo "[FAIL] LEAK_DETECTED field=any location=$(basename "$f")"
    FAIL=1
  fi
done

[ $FAIL -eq 0 ] && echo "[PASS] Marker in signature+attributes(key/value/nested)+summary simultaneously — no alternate leak path"
exit $FAIL
