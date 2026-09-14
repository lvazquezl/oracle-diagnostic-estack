#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 34/9.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-limits-multiple-invocations.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'cada una se representa como un' "$S" && echo "[PASS] declara que cada invocación se representa por separado" || { echo "[FAIL] falta la regla de separación"; FAIL=1; }
grep -q 'policy_sources_count: 2' "$FX" && grep -q 'collapsed: false' "$FX" \
  && echo "[PASS] fixture declara 2 policy sources sin colapsar" || { echo "[FAIL] falta el resultado esperado en la fixture"; FAIL=1; }
exit $FAIL
