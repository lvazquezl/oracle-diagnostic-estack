#!/usr/bin/env bash
# PHASE 11 — RCA SIGNATURE ALLOWLIST & OUTPUT LEAK PREVENTION MICRO-HARDENING, § 4.8: recursive
# scan of every synthetic signature marker across JSON, Markdown, evidence manifest, stdout
# (no --out) and stderr — all must be absent.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_sig_all_surfaces_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/signature_various_unknown_shapes.json" "$TMPDIR/fixture.json"

# JSON/Markdown/manifest via files
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result.json" "report.md" "manifest.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }
for f in result.json report.md manifest.json "$RCA_ENGINE_RUN_STDERR_FILE"; do
  loc="$f"; [ -f "$TMPDIR/$f" ] && loc="$TMPDIR/$f"
  if grep -qF "$MARKER" "$loc" 2>/dev/null; then
    echo "[FAIL] LEAK_DETECTED field=signature location=$(basename "$loc")"
    FAIL=1
  fi
done

# stdout (no --out) — the payload prints to stdout directly.
STDOUT_FILE="$TMPDIR/stdout.log"
( cd "$TMPDIR" && PYTHONPATH="$ROOT" python3 -m rca_engine.cli --fixture fixture.json ) > "$STDOUT_FILE" 2>"$TMPDIR/stdout_stderr.log"
if grep -qF "$MARKER" "$STDOUT_FILE"; then
  echo "[FAIL] LEAK_DETECTED field=signature location=stdout"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] Recursive scan across JSON/Markdown/manifest/stdout/stderr: all synthetic signature markers absent"
exit $FAIL
