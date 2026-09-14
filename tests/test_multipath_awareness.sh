#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/multipath-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'No ejecutar multipathd reconfigure' "$S" && echo "[PASS] prohíbe multipathd reconfigure" || { echo "[FAIL] falta la prohibición de reconfigure"; FAIL=1; }
grep -qi 'nunca se asume que multipath no está configurado' "$S" && echo "[PASS] prohíbe asumir ausencia de multipath sin collector" || { echo "[FAIL] falta la regla de no asumir ausencia"; FAIL=1; }
exit $FAIL
