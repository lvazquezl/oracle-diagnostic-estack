#!/usr/bin/env bash
# PHASE 11 — RCA STRUCTURED EVIDENCE SANITIZATION & OUTPUT LEAK PREVENTION HARDENING, § 5:
# comprehensive end-to-end CLI run with markers in every structured field simultaneously — all
# 4 output surfaces (JSON, Markdown, manifest, stderr) plus re-running the SAME sanitized fixture
# a second time (idempotency: stable output, no re-leak, token map never merged into artifacts).
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tests/lib/rca_engine_e2e_helpers.sh"
FAIL=0
MARKER="SYNTHETIC_SECRET_DO_NOT_USE"

TMPDIR="$ROOT/tests/.tmp_rca_cli_e2e_no_leak_$$"
mkdir -p "$TMPDIR"
trap 'rm -rf "$TMPDIR"' EXIT
cp "$ROOT/tests/fixtures/rca_engine/marker_combined_all_fields.json" "$TMPDIR/fixture.json"

rca_engine_run "$TMPDIR" "fixture.json" "" "" "result1.json" "report1.md" "manifest1.json" "tokenmap1.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] first run exit $RCA_ENGINE_RUN_RC"; sed 's/^/    /' "$RCA_ENGINE_RUN_STDERR_FILE"; exit 1; }

for f in "$TMPDIR/result1.json" "$TMPDIR/report1.md" "$TMPDIR/manifest1.json" "$RCA_ENGINE_RUN_STDERR_FILE"; do
  if grep -qF "$MARKER" "$f" 2>/dev/null; then
    echo "[FAIL] LEAK_DETECTED field=any location=$(basename "$f")"
    FAIL=1
  fi
done

# the token map DOES legitimately contain the raw value (by design, in its own separate file) —
# confirm it is NOT merged into any of the model/report-facing artifacts.
if grep -qF "TGT-" "$TMPDIR/result1.json" && grep -qF "$MARKER" "$TMPDIR/tokenmap1.json"; then
  echo "[PASS] token map correctly isolated: result.json holds only the token, tokenmap1.json holds the raw mapping separately"
else
  echo "[FAIL] token/raw-value separation between result.json and tokenmap1.json not as expected"
  FAIL=1
fi
# idempotency: re-run the SAME original fixture a second time -> stable output (excluding
# generated_at), and the token map for the same raw values is identical (deterministic tokens).
rca_engine_run "$TMPDIR" "fixture.json" "" "" "result2.json" "" "" "tokenmap2.json"
[ "$RCA_ENGINE_RUN_RC" -eq 0 ] || { echo "[FAIL] second run exit $RCA_ENGINE_RUN_RC"; exit 1; }

OUT=$(rca_engine_read_json "$TMPDIR" "
import json
r1 = json.load(open('result1.json')); r2 = json.load(open('result2.json'))
r1.pop('generated_at'); r2.pop('generated_at')
assert r1 == r2, 'sanitized re-run diverged (excluding generated_at)'
tm1 = json.load(open('tokenmap1.json')); tm2 = json.load(open('tokenmap2.json'))
assert tm1 == tm2, 'token map not stable across identical re-runs'
print('ENGINE_OK')
" 2>&1)
if echo "$OUT" | grep -q "^ENGINE_OK$"; then
  echo "[PASS] Idempotent: identical sanitized output and token map across two runs of the same fixture"
else
  echo "[FAIL] $OUT"
  FAIL=1
fi

[ $FAIL -eq 0 ] && echo "[PASS] CLI E2E: NO_LEAK across JSON/Markdown/manifest/stderr, token map correctly isolated"
exit $FAIL
