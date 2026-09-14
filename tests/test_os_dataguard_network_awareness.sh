#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 73.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/dataguard-network-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'apply lag, no transport lag' "$S" && echo "[PASS] distingue apply lag de transport lag" || { echo "[FAIL] falta la distinción apply/transport lag"; FAIL=1; }
grep -q 'route_to_remote_site' "$S" && echo "[PASS] declara route_to_remote_site en el output" || { echo "[FAIL] falta route_to_remote_site"; FAIL=1; }
exit $FAIL
