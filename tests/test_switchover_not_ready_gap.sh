#!/usr/bin/env bash
# dataguard/switchover-readiness reporta NOT_READY cuando hay un gap sin resolver.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

grep -q 'Q-DG-ARCHIVE-GAP-001' "$ROOT/tests/fixtures/19c-switchover-not-ready.yaml" && echo "[PASS] fixture switchover-not-ready incluye evidencia de gap" || { echo "[FAIL] falta evidencia de gap"; FAIL=1; }
grep -qi 'blocking_findings' "$ROOT/skills/dataguard/switchover-readiness/SKILL.md" && echo "[PASS] switchover-readiness declara blocking_findings" || { echo "[FAIL] falta blocking_findings"; FAIL=1; }

exit $FAIL
