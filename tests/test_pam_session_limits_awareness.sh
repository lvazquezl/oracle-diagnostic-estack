#!/usr/bin/env bash
# PHASE 9 — EFFECTIVE PROCESS LIMITS & SYSTEMD/PAM SOURCE-OF-TRUTH HARDENING, sección 42.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/ulimits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-session-oracle-limit.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'get_pam_limit_configuration' "$S" && echo "[PASS] declara el collector get_pam_limit_configuration" || { echo "[FAIL] falta get_pam_limit_configuration"; FAIL=1; }
grep -q 'launch_context: PAM_LOGIN' "$FX" && echo "[PASS] fixture declara launch_context PAM_LOGIN" || { echo "[FAIL] falta launch_context PAM_LOGIN en la fixture"; FAIL=1; }
exit $FAIL
