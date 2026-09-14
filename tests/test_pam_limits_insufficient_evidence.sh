#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS APPLICABILITY & PROCESS CONSTRAINT SCOPE MICRO-HARDENING, sección 42/17.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pamname-unknown-stack.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'pam_limits.applicability = INSUFFICIENT_EVIDENCE' "$S" && echo "[PASS] declara INSUFFICIENT_EVIDENCE cuando la pila PAM no es legible" || { echo "[FAIL] falta la rama INSUFFICIENT_EVIDENCE"; FAIL=1; }
grep -q 'applicability: INSUFFICIENT_EVIDENCE' "$FX" && echo "[PASS] fixture declara INSUFFICIENT_EVIDENCE" || { echo "[FAIL] falta el resultado en la fixture"; FAIL=1; }
grep -q 'applicability_assumed: false' "$FX" && echo "[PASS] fixture declara que no se asume applicability" || { echo "[FAIL] falta applicability_assumed: false"; FAIL=1; }
exit $FAIL
