#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 34.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-custom-conf-policy-source.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'CUSTOM_CONF' "$S" && echo "[PASS] declara el modo CUSTOM_CONF" || { echo "[FAIL] falta CUSTOM_CONF"; FAIL=1; }
grep -q 'mode: CUSTOM_CONF' "$FX" && echo "[PASS] fixture declara mode CUSTOM_CONF" || { echo "[FAIL] falta mode CUSTOM_CONF en la fixture"; FAIL=1; }
exit $FAIL
