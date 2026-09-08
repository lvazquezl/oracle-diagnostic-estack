#!/usr/bin/env bash
# dataguard/archive-gaps es thread-aware en RAC; fixture RAC primary+standby con gap existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

[ -f "$ROOT/tests/fixtures/19c-rac-primary-standby.yaml" ] && echo "[PASS] fixture RAC con gap por thread existe" || { echo "[FAIL] falta fixture"; FAIL=1; }
grep -q 'THREAD_SPECIFIC_GAP' "$ROOT/skills/dataguard/archive-gaps/SKILL.md" && echo "[PASS] archive-gaps declara THREAD_SPECIFIC_GAP" || { echo "[FAIL] falta la clasificación"; FAIL=1; }

exit $FAIL
