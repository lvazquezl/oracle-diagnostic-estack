#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'pam_limits:' "$S" && echo "[PASS] declara el bloque pam_limits en el output" || { echo "[FAIL] falta el bloque pam_limits"; FAIL=1; }
grep -qi 'applicability: APPLICABLE|NOT_APPLICABLE|INSUFFICIENT_EVIDENCE|NOT_ASSESSED' "$S" \
  && echo "[PASS] declara los 4 estados de applicability" || { echo "[FAIL] faltan los estados de applicability"; FAIL=1; }
grep -qi 'pam_limits_module_present' "$S" && echo "[PASS] declara pam_limits_module_present como campo separado de la sesión PAM" || { echo "[FAIL] falta pam_limits_module_present"; FAIL=1; }
exit $FAIL
