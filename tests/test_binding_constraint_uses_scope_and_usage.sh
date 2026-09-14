#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 44/24/25.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/process-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'binding_constraint' "$S" && echo "[PASS] declara binding_constraint en el output" || { echo "[FAIL] falta binding_constraint"; FAIL=1; }
if grep -q 'se infiere usando' "$S" && grep -q 'launch_context. + .process membership' "$S"; then
  echo "[PASS] declara los factores usados para inferir binding_constraint"
else
  echo "[FAIL] faltan los factores de inferencia"; FAIL=1
fi
exit $FAIL
