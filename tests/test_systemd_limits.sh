#!/usr/bin/env bash
# PHASE 9 — OS PLATFORM DIAGNOSTICS & HARDENING, sección 69.
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 42:
# eliminada la aserción "effective = most restrictive of limits.conf and systemd" que
# institucionalizaba el modelo incorrecto.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
grep -qi 'NOT_APPLICABLE.*nunca se asume que sí\|nunca se asume que sí' "$S" \
  && echo "[PASS] declara NOT_APPLICABLE cuando no corre bajo systemd" || { echo "[FAIL] falta la regla NOT_APPLICABLE"; FAIL=1; }
grep -qi 'el valor efectivo es el más' "$S" \
  && { echo "[FAIL] SKILL.md todavía declara la regla incorrecta 'el valor efectivo es el más restrictivo de ambos'"; FAIL=1; } \
  || echo "[PASS] no declara la regla universal incorrecta de mínimo entre systemd y limits.conf"
grep -qi 'PAM applicability model' "$S" \
  && echo "[PASS] declara la sección PAM applicability model" || { echo "[FAIL] falta la sección PAM applicability model"; FAIL=1; }
grep -qi 'pam_limits.so ACTIVE' "$S" \
  && echo "[PASS] distingue PAM session present de pam_limits.so active" || { echo "[FAIL] falta la distinción session/module"; FAIL=1; }
grep -qi 'PAMName=' "$S" && echo "[PASS] declara PAMName= como evidencia explícita requerida" || { echo "[FAIL] falta la referencia a PAMName="; FAIL=1; }
exit $FAIL
