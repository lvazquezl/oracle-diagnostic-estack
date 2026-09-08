#!/usr/bin/env bash
# dataguard/apply reconoce APPLYING_LOG/WAIT_FOR_LOG como estado normal.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/apply/SKILL.md"

grep -q 'APPLYING_LOG' "$S" && grep -q 'WAIT_FOR_LOG' "$S" && echo "[PASS] apply reconoce estados normales" || { echo "[FAIL] falta estado normal"; FAIL=1; }

exit $FAIL
