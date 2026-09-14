#!/usr/bin/env bash
# PHASE 9 — PAM LIMITS POLICY SOURCE & PID CONTROLLER IDENTITY MICRO-HARDENING, sección 34/8.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
S="$ROOT/skills/os/systemd-limits/SKILL.md"
U="$ROOT/skills/os/ulimits/SKILL.md"
FX="$ROOT/tests/fixtures/ol8-pam-custom-conf-policy-source.yaml"

[ -f "$S" ] || { echo "[FAIL] falta $S"; exit 1; }
[ -f "$U" ] || { echo "[FAIL] falta $U"; exit 1; }
[ -f "$FX" ] || { echo "[FAIL] falta $FX"; exit 1; }
grep -qi 'se asumen concurrentes ni' "$S" && echo "[PASS] declara que limits.conf/limits.d nunca se asumen concurrentes con conf=" || { echo "[FAIL] falta la prohibición de concurrencia"; FAIL=1; }
grep -qi 'limits.conf./.\?limits.d. por defecto' "$U" \
  && echo "[PASS] os/ulimits declara que CUSTOM_CONF nunca usa la fuente por defecto" || { echo "[FAIL] falta la regla en os/ulimits"; FAIL=1; }
grep -q 'default_source_assumed: false' "$FX" && echo "[PASS] fixture confirma default_source_assumed: false" || { echo "[FAIL] falta la confirmación en la fixture"; FAIL=1; }
exit $FAIL
