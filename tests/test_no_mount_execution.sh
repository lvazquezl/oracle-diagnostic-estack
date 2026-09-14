#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/mount-options/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'Nunca remonta ni cambia opciones' "$S" && echo "[PASS] prohíbe remontar/cambiar opciones" || { echo "[FAIL] falta la prohibición de remount"; FAIL=1; }
grep -qi 'NOT_EXECUTED' "$S" && echo "[PASS] declara manual_action NOT_EXECUTED" || { echo "[FAIL] falta NOT_EXECUTED"; FAIL=1; }
exit $FAIL
