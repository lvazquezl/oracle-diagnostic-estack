#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 71.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/io-performance/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'No concluir storage root cause con util% aislado' "$S" && echo "[PASS] cita la regla fuente anti-util%-aislado" || { echo "[FAIL] falta la cita"; FAIL=1; }
grep -qi 'nunca por .util%. aislado' "$S" && echo "[PASS] declara severidad HIGH sólo con evidencia combinada" || { echo "[FAIL] falta la regla de severidad combinada"; FAIL=1; }
exit $FAIL
