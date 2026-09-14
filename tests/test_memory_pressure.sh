#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 67.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/memory-pressure/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'HEALTHY|WARNING|DEGRADED|CRITICAL' "$S" && echo "[PASS] declara los 4 estados" || { echo "[FAIL] faltan los estados"; FAIL=1; }
grep -qi 'nunca una sola métrica aislada\|nunca evidencia combinada' "$S" \
  && echo "[PASS] requiere evidencia combinada para CRITICAL" || { echo "[FAIL] falta la regla de evidencia combinada"; FAIL=1; }
exit $FAIL
