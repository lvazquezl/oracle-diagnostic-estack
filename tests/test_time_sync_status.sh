#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 72.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/time-sync/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'SYNCED|UNSYNCED|DEGRADED|UNKNOWN' "$S" && echo "[PASS] declara los 4 estados normalizados" || { echo "[FAIL] faltan los estados"; FAIL=1; }
grep -qi 'CRITICAL.\{0,20\}si .UNSYNCED. en un nodo RAC' "$S" && echo "[PASS] declara CRITICAL para UNSYNCED en RAC" || { echo "[FAIL] falta la regla CRITICAL en RAC"; FAIL=1; }
exit $FAIL
