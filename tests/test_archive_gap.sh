#!/usr/bin/env bash
# dataguard/archive-gaps detecta gaps y el fixture correspondiente existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

[ -f "$ROOT/tests/fixtures/19c-archive-gap.yaml" ] && echo "[PASS] fixture de gap simple existe" || { echo "[FAIL] falta fixture"; FAIL=1; }
grep -q 'V\$ARCHIVE_GAP' "$ROOT/skills/dataguard/archive-gaps/SKILL.md" && echo "[PASS] archive-gaps usa V\$ARCHIVE_GAP" || { echo "[FAIL] falta referencia"; FAIL=1; }

exit $FAIL
