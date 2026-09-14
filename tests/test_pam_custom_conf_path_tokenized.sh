#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 35.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-custom-conf-policy-source.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q 'source_token: string|null' "$S" && echo "[PASS] declara source_token tokenizado en el output" || { echo "[FAIL] falta source_token"; FAIL=1; }
grep -q 'source_token: "SOURCE_TOKEN_CUSTOM_001"' "$FX" && echo "[PASS] fixture usa un source_token tokenizado, nunca el path crudo" || { echo "[FAIL] falta el source_token en la fixture"; FAIL=1; }
exit $FAIL
