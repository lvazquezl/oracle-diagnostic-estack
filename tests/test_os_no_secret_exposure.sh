#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 75.
# Variante de dominio de test_secret_detection.sh (repo-wide) — aquí se valida que los
# skills os/* que tocan credenciales/wallet declaren explícitamente su prohibición.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/security-filesystem-awareness/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'nunca lee contenido del wallet' "$S" && echo "[PASS] os/security-filesystem-awareness nunca lee el contenido del wallet" || { echo "[FAIL] falta la prohibición de leer el wallet"; FAIL=1; }
grep -qi 'Contenido del wallet nunca leído ni transmitido' "$S" && echo "[PASS] declara explícitamente que el contenido nunca se transmite" || { echo "[FAIL] falta la declaración de no-transmisión"; FAIL=1; }
exit $FAIL
