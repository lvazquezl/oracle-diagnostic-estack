#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -q 'NO  → pam_limits.applicability = NOT_APPLICABLE' "$S" \
  && echo "[PASS] declara NOT_APPLICABLE cuando PAMName no está configurado" || { echo "[FAIL] falta la rama NOT_APPLICABLE por ausencia de PAMName"; FAIL=1; }
grep -q 'NO → pam_limits.applicability = NOT_APPLICABLE' "$S" \
  && echo "[PASS] declara NOT_APPLICABLE cuando pam_limits.so no está presente en la pila" || { echo "[FAIL] falta la rama NOT_APPLICABLE por módulo ausente"; FAIL=1; }
exit $FAIL
