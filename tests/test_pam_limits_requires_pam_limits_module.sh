#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pamname-with-pam-limits.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'get_pam_limits_applicability' "$S" && echo "[PASS] declara el collector get_pam_limits_applicability" || { echo "[FAIL] falta el collector"; FAIL=1; }
grep -q 'applicability: APPLICABLE' "$FX" && echo "[PASS] fixture declara APPLICABLE con pam_limits.so confirmado" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
exit $FAIL
