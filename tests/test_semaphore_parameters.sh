#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/semaphores/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'SEMMSL' "$S" && grep -q 'SEMMNS' "$S" && echo "[PASS] declara SEMMSL/SEMMNS" || { echo "[FAIL] faltan SEMMSL/SEMMNS"; FAIL=1; }
grep -qi 'No recomendar valores sin contexto' "$S" && echo "[PASS] cita la prohibición de recomendar sin contexto de PROCESSES" || { echo "[FAIL] falta la cita"; FAIL=1; }
exit $FAIL
