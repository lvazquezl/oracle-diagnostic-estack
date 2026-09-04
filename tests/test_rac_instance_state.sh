#!/usr/bin/env bash
# rac/instance-state distingue status/active_state, no reinicia instancias.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/rac/instance-state/SKILL.md"

grep -q 'active_state' "$S" && echo "[PASS] rac/instance-state distingue active_state" || { echo "[FAIL] falta active_state"; FAIL=1; }
grep -qi 'no reinicia ni relocaliza instancias' "$S" && echo "[PASS] prohibición explícita de reinicio" || { echo "[FAIL] falta prohibición"; FAIL=1; }

exit $FAIL
