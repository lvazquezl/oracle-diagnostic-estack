#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/ephemeral-ports/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'os/rac-interconnect-awareness' "$S" && echo "[PASS] correlaciona con os/rac-interconnect-awareness" || { echo "[FAIL] falta la correlación RAC"; FAIL=1; }
grep -qi 'compiten por el mismo pool de puertos' "$S" \
  && echo "[PASS] declara la competencia por el pool de puertos en RAC" || { echo "[FAIL] falta la regla de competencia por puertos"; FAIL=1; }
exit $FAIL
