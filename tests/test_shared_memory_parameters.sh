#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/shared-memory/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'No usar fórmulas obsoletas universalmente' "$S" && echo "[PASS] cita la prohibición de fórmula obsoleta universal" || { echo "[FAIL] falta la cita"; FAIL=1; }
grep -q 'shmmax_bytes' "$S" && echo "[PASS] declara shmmax_bytes en el output" || { echo "[FAIL] falta shmmax_bytes"; FAIL=1; }
exit $FAIL
