#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 9/46.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
D="$ROOT/docs/OS_READONLY_COLLECTOR_MODEL.md"

[ -f "$D" ] || { echo "[FAIL] falta $D"; exit 1; }
grep -q '`get_pam_limits_applicability`' "$D" && echo "[PASS] catálogo declara get_pam_limits_applicability" || { echo "[FAIL] falta get_pam_limits_applicability en el catálogo"; FAIL=1; }
grep -qi 'service.\? allowlisted/validado' "$D" && echo "[PASS] declara que el service está allowlisted/validado" || { echo "[FAIL] falta la validación de service"; FAIL=1; }
grep -qi 'nunca infiere applicability de la sola presencia de .PAMName=' "$D" \
  && echo "[PASS] declara que nunca infiere applicability de PAMName= aislado" || { echo "[FAIL] falta la prohibición de inferencia"; FAIL=1; }
exit $FAIL
