#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 41/43/27.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-systemd-configuration-effective-mismatch.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'CONFIGURATION_EFFECTIVE_MISMATCH' "$S" && echo "[PASS] declara CONFIGURATION_EFFECTIVE_MISMATCH" || { echo "[FAIL] falta CONFIGURATION_EFFECTIVE_MISMATCH"; FAIL=1; }
grep -qi 'nunca se asume una causa única automáticamente' "$S" && echo "[PASS] prohíbe inferir causa única automáticamente" || { echo "[FAIL] falta la prohibición de causa única"; FAIL=1; }
grep -qi 'nunca recomienda reiniciar el servicio Oracle/systemd automáticamente' "$S" \
  && echo "[PASS] prohíbe recomendar reinicio automático" || { echo "[FAIL] falta la prohibición de reinicio automático"; FAIL=1; }
grep -q 'single_cause_inferred: false' "$FX" && echo "[PASS] fixture declara single_cause_inferred: false" || { echo "[FAIL] falta single_cause_inferred en la fixture"; FAIL=1; }
exit $FAIL
