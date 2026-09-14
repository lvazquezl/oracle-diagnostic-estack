#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 34.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-default-policy-source.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -q '# PAM limits policy source model' "$S" && echo "[PASS] declara la sección PAM limits policy source model" || { echo "[FAIL] falta la sección"; FAIL=1; }
grep -qi 'sin .conf=.: awareness de' "$S" && echo "[PASS] declara el modo DEFAULT" || { echo "[FAIL] falta el modo DEFAULT"; FAIL=1; }
grep -q 'mode: DEFAULT' "$FX" && echo "[PASS] fixture declara mode DEFAULT" || { echo "[FAIL] falta mode DEFAULT en la fixture"; FAIL=1; }
exit $FAIL
