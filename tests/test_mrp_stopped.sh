#!/usr/bin/env bash
# dataguard/apply detecta MRP ausente y el fixture correspondiente existe.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/apply/SKILL.md"

grep -qi 'MRP ausente' "$S" && echo "[PASS] apply detecta MRP ausente" || { echo "[FAIL] falta detección de MRP ausente"; FAIL=1; }
[ -f "$ROOT/tests/fixtures/19c-mrp-stopped.yaml" ] && echo "[PASS] fixture mrp-stopped existe" || { echo "[FAIL] falta fixture"; FAIL=1; }

exit $FAIL
