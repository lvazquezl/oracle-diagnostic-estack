#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 45/20.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/open-files/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'sin evidencia de uso actual real, no se declara riesgo sólo por un valor configurado aislado' "$S" \
  && echo "[PASS] prohíbe declarar riesgo sólo por un valor configurado aislado" || { echo "[FAIL] falta la prohibición"; FAIL=1; }
grep -q 'límite relevante para el risk model' "$S" \
  && echo "[PASS] declara que el risk model usa el límite efectivo" || { echo "[FAIL] falta la regla del risk model"; FAIL=1; }
exit $FAIL
