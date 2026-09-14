#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/mtu/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Nunca recomendar jumbo frames' "$S" && echo "[PASS] prohíbe recomendar jumbo frames sin evidencia end-to-end" || { echo "[FAIL] falta la prohibición de jumbo frames"; FAIL=1; }
grep -qi 'MTU 9000' "$S" && echo "[PASS] referencia MTU 9000 explícitamente" || { echo "[FAIL] falta la referencia a MTU 9000"; FAIL=1; }
exit $FAIL
