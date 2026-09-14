#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/bonding/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'active_slave' "$S" && echo "[PASS] declara active_slave" || { echo "[FAIL] falta active_slave"; FAIL=1; }
grep -qi 'aggregation.*no .bonding.*mapeado explícitamente\|terminología .aggregation' "$S" \
  && echo "[PASS] mapea terminología Solaris aggregation vs bonding" || { echo "[FAIL] falta el mapeo de terminología Solaris"; FAIL=1; }
exit $FAIL
