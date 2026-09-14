#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pamname-without-pam-limits.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'PAMName DOES NOT BY ITSELF PROVE\|PAMName.\? sólo prueba que se .\?solicita' "$S" \
  && echo "[PASS] declara que PAMName no prueba por sí sola pam_limits activo" || { echo "[FAIL] falta la regla"; FAIL=1; }
grep -q 'applicability: NOT_APPLICABLE' "$FX" && echo "[PASS] fixture declara NOT_APPLICABLE con PAMName sin pam_limits.so" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
exit $FAIL
