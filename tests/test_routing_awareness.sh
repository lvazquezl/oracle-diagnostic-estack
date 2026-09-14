#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 70.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/routing/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'get_routes' "$S" && echo "[PASS] formaliza el collector get_routes de Fase 4" || { echo "[FAIL] falta la referencia a get_routes"; FAIL=1; }
grep -qi 'inventa un destino esperado' "$S" && echo "[PASS] prohíbe inventar destinos esperados" || { echo "[FAIL] falta la prohibición de destinos inventados"; FAIL=1; }
exit $FAIL
