#!/usr/bin/env bash
# dataguard/standby-redo-logs detecta SIZE_MISMATCH contra el online redo del primary.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/dataguard/standby-redo-logs/SKILL.md"

grep -q 'SIZE_MISMATCH' "$S" && echo "[PASS] SRL declara SIZE_MISMATCH" || { echo "[FAIL] falta SIZE_MISMATCH"; FAIL=1; }

exit $FAIL
