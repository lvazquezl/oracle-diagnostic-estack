#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 73.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/rman-media-manager-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'No ejecutar vendor jobs' "$S" && echo "[PASS] cita la prohibición de ejecutar vendor jobs" || { echo "[FAIL] falta la cita"; FAIL=1; }
grep -qi 'nunca asume el vendor/producto de media manager' "$S" \
  && echo "[PASS] prohíbe asumir el vendor sin declaración del Target Profile" || { echo "[FAIL] falta la prohibición de asumir vendor"; FAIL=1; }
exit $FAIL
